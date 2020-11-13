// Image/J (Fiji) macro to implement Breast Peripheral Equalization.
// Image J's "Auto Threshold" is replaced by AIA ObjectMask.
// Input is a directory containing DICOM format files or a single DICOM file.
// Second input is the complete path to the AIA Object Mask executable
// Separator between inputs is a space.
// Input DICOMs should be attenuation images (possibly with inverted luts).
// ex.) beware quotes
// java -jar E:\source\Java\Fiji\fiji-win64\Fiji.app\jars\ij-1.52p.jar
// -ijpath E:\source\Java\Fiji\fiji-win64\Fiji.app -batch
// "E:\source\Java\Fiji\fiji-win64\Fiji.app\macros\Breast_Enh1_AIA.ijm"
// "E:\data\CDor_3\mammo\Jordana_CEM\Patient_001 C:\Users\eric\kauai\bin\ObjectMask.exe"
// by keesh (keesh@ieee.org)

// Linear rescales an image to [0,1] in place
function linearIntensyScale(imageTitle) {
	selectImage(imageTitle);  
	run("32-bit");
	getRawStatistics(nPixels, mean, min, max);
	run("Subtract...", "value=&min");
	scale = 1 / (max-min);
	run("Multiply...", "value=&scale");
	setMinAndMax(0, 1);
}

// This function returns the value of the specified
// tag  (e.g., "0010,0010") as a string. Returns ""
// if the tag is not found.
function getTag(tag) {
	info = getImageInfo();
    index1 = indexOf(info, tag);
    if (index1==-1) return "";
    index1 = indexOf(info, ":", index1);
    if (index1==-1) return "";
    index2 = indexOf(info, "\n", index1);
    value = substring(info, index1+1, index2);
    return value;
}
// Gets the Presentation LUT Shape Attribute DICOM tag "2050,0020" for the active image.
// Actually just inverted for display.
function getInverted() {
	invert_image = 0;
	inverted = getTag("2050,0020");
   	if (inverted != ""){
    	inverted = toLowerCase(inverted);
    	if (indexOf(inverted, "inverse") != -1){
    		invert_image = 1;
    	}
   	}
   	return invert_image;
}


function applyBreastPeripheralEqualization(input, output, filename, obj_mask_exec) {
	// set up
	print("Processing file: " + input + filename);
	open(input + filename); 
	dotIndex = lastIndexOf(filename, ".");
	title = substring(filename, 0, dotIndex);
	run("Duplicate...", "title=I1");
	run("Duplicate...", "title=I2");
	run("Duplicate...", "title=I3");
	run("Duplicate...", "title=I1_THRESH");
	
	// Segmentation by thresholding (could probably consolidate following steps)
	// bgnd=0, fgnd=1
	selectImage("I1");  
   	invert_image = getInverted();

    niiSuffix = ".nii";
    selectImage("I1_THRESH");
    if(invert_image){
    	run("Invert");
        niiFile = output + title + "_invert" + niiSuffix;
        print("Inverted image: " + title);
    }
    else{
        niiFile = output + title + niiSuffix;
    }
    run("NIfTI-1", "save=["+niiFile+"]");
    maskInputFile = niiFile;

    resultName="_mask";
    resultSuffix=".nii";
    outputFile = output + title + resultName + resultSuffix;
    // need to have each arg as a sep string
    exec_out = exec(obj_mask_exec, "-t", "mammo-breast", "-g", "-d", "uint8", "-i", maskInputFile, "-m", outputFile);
    print(exec_out);
   	open(outputFile);
	run("Duplicate...", "title=M1");
	run("Duplicate...", "title=M1_DBG");
	selectImage("M1_DBG");
	run("Multiply...", "value=255.000");  // for viz
	selectImage("M1");
	rename("S");

	//Low-pass filter
	selectImage("I2");  
	// was 20, 1
	run("LowpassFilters ", "lowpass=Butterworth threshold=40 order=2"); 
	selectImage("Inverse FFT of I2");
	rename("B");

	//Low-pass mask [0,1]
	imageCalculator("Multiply create 32-bit", "B","S");
	selectImage("Result of B");
	rename("M");
	linearIntensyScale("M");

	// M ^ 0.75
	run("Gamma...", "value=0.75");
	rename("M_75");

	// I / (M ^ 0.75)  
	selectImage("I3");
	run("32-bit");
	imageCalculator("Divide create 32-bit", "I3","M_75");

	//Output
	resultName="_result";
	resultSuffix=".nii";
	selectImage("Result of I3");
	rename(resultName);
	selectImage(resultName);
	getStatistics(area, mean, min, max, std);  // This calculation excludes Inf
	
	// Change Inf values from above division to left-most (smallest value) --  may need to change Inf to some other value
	changeValues(1/0, 1/0, max);

	//scale when converting is ON by default in both IJ and FIJI
	run("Conversions...", " ");
	run("16-bit");
	run("Invert");
	outputFile = output + title + resultName + resultSuffix;
	run("NIfTI-1", "save=["+outputFile+"]");
	print("Processed: " + outputFile);

	// BEG DBG CODE
	selectImage("I1");
	run("Invert");
	setOption("ScaleConversions", true);
	run("8-bit");
	run("Merge Channels...", "c1=M1_DBG c4=I1 create keep");
	selectImage("Composite");
    resultName="_thresh_overlay";
    resultSuffix=".png";
    outputFile = output + title + resultName + resultSuffix;
    saveAs("PNG", outputFile);
	// END DBG CODE
	
	//Clean up
	close("*");  // Closes all images
}  // apply...

//NOTE-- Using batch mode causes weird Windows focus errors on second pass after run LowpassFilters if the class is not compiled.
setBatchMode(true);
args = getArgument();

// May need to try different seps
// "E:\data\CDor_3\mammo\Jordana_CEM\Patient_004 C:\Users\eric\kauai\bin\ObjectMask.exe"

args_array = split(args, "");
input_output  = args_array[0];
obj_mask_exec = args_array[1];

if (File.isDirectory(input_output)) {
	list = getFileList(input_output);
	input_output = input_output + File.separator;
}
else if (File.exists(input_output)) {
	file_base = File.getName(input_output);
	list = newArray(file_base);
	input_output = File.getDirectory(input_output);
}
else{
	print("Invalid input file or directory: " + input_output);
	exit();
}
if ( ! File.exists(obj_mask_exec)) {
	print("Invalid ObjectMask executable: " + obj_mask_exec);
	exit();
}

for (i = 0; i < list.length; i++)
	// input dir, output dir, filename
	applyBreastPeripheralEqualization(input_output, input_output, list[i], obj_mask_exec);
setBatchMode(false); 
print("fin")