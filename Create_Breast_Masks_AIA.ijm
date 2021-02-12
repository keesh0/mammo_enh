// Image/J (Fiji) macro to implement AIA Breast mask extraction.
// Input is a directory containing DCM format files.
// Second input is the complete path to the AIA Object Mask executable
// Separator between inputs is a space.
// Input DCMs should be inverted LUT images (air=dark body=bright).
// ex.) beware quotes
// java -jar E:\source\Java\Fiji\fiji-win64\Fiji.app\jars\ij-1.52p.jar -ijpath E:\source\Java\Fiji\fiji-win64\Fiji.app -batch "E:\source\Java\Fiji\fiji-win64\Fiji.app\macros\Create_Breast_Masks_AIA.ijm" "E:\data\CDor_3\mammo\Jordana_CEM\Patient_001 C:\Users\eric\kauai\bin\ObjectMask.exe"
// by keesh (keesh@ieee.org)


// This function returns the value of the specified
// tag  (e.g., "0010,0010") as a string. Returns ""
// if the tag is not found.
// TODO -- Fix this for 
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

// Checks the 0008,0008  Image Type: ORIGINAL\PRIMARY\\LOW_ENERGY wrt HIGH_ENERGY for the active image
function isHighEnergy() {
	high_image = 0;
	image_type = getTag("0008,0008");
   	if (image_type != ""){
    	image_type = toLowerCase(image_type);
    	if (indexOf(image_type, "high") != -1){
    		high_image = 1;
    	}
   	}
   	return high_image;
}


function applyAIAMaskExtraction(input, output, filename, obj_mask_exec) {
	// const
	niiSuffix = ".nii";
    resultName= "_mask";

	// set up
	print("Processing DCM file: " + input + filename);
	open(input + filename); 
	run("Duplicate...", "title=I1");
	dotIndex = lastIndexOf(filename, ".");
	title = substring(filename, 0, dotIndex);
	current_uid = getTag("0020,000E");
	is_high = isHighEnergy();
	is_high_str = "high";
	if (! is_high){
		is_high_str = "low";
	}
	// May need to make easier for parser
	seriesId = "_" + current_uid + "_" + is_high_str;

	// DICOM processing assumed
	// Invert image to obtain an attenuation image
	run("Invert");
    niiFile = output + title + niiSuffix;
    print("Converted image: " + title);
    run("NIfTI-1", "save=["+niiFile+"]");
	open(niiFile);
	
    maskInputFile = niiFile;
    outputFile = output + title + resultName + seriesId + niiSuffix;
    // need to have each arg as a sep string
    // bgnd=0, fgnd=1
    exec_out = exec(obj_mask_exec, "-t", "mammo", "-d", "uint8", "-i", maskInputFile, "-m", outputFile);
    print(exec_out);
    print("Created mask for low energy image: " + title);

	// BEG DBG CODE	
	open(outputFile);
	run("Duplicate...", "title=M1_DBG");
	selectImage("M1_DBG");
	run("Multiply...", "value=255.000");  // for viz
	selectImage("I1");
	setOption("ScaleConversions", true);
	run("8-bit");
	run("Merge Channels...", "c1=M1_DBG c4=I1 create keep");
	selectImage("Composite");
    resultName="_thresh_overlay";
    resultSuffix=".png";
    outputFile = output + title + resultName + seriesId + resultSuffix;
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
if (args_array.length==1 && args_array[0]=="--version") {
	print("0.0.1");
	exit();
}

input_output  = args_array[0];
obj_mask_exec = args_array[1];

low_series_inst_uid = newArray();
low_base_fname = newArray();
if ( !File.isDirectory(input_output)) {
	print("Invalid input directory: " + input_output);
	exit();
}
if ( ! File.exists(obj_mask_exec)) {
	print("Invalid ObjectMask executable: " + obj_mask_exec);
	exit();
}

list = getFileList(input_output);
input_output = input_output + File.separator;
for (i = 0; i < list.length; i++) {
	if( endsWith(list[i], ".dcm") ){
		// input dir, output dir, filename
		applyAIAMaskExtraction(input_output, input_output, list[i], obj_mask_exec); 
	}
}

setBatchMode(false); 
print("fin")