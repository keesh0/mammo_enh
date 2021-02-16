// Image/J (Fiji) macro to implement Breast Peripheral Equalization.
// Image J's "Auto Threshold" is replaced by AIA ObjectMask.
// Input is a directory containing NIFTI format files or a single NIFTI file.
// If input is a file, please specify the low and high energy breast masks.
// If input is a directory then we can find the low and high energy masks in this script (testing mode).
// Second input is the complete path to the AIA Object Mask executable
// Separator between inputs is a space.
// Input NIFTIs should be inverted attenuation images (air=dark body=bright).
// ex.) beware quotes
// java -jar E:\source\Java\Fiji\fiji-win64\Fiji.app\jars\ij-1.52p.jar -ijpath E:\source\Java\Fiji\fiji-win64\Fiji.app -batch "E:\source\Java\Fiji\fiji-win64\Fiji.app\macros\Breast_Enh1_AIA.ijm" "E:\data\CDor_3\mammo\Jordana_CEM\Patient_001\2.25.50003046908655299155646025163908180623.nii  E:\data\CDor_3\mammo\Jordana_CEM\Patient_001\2.25.56988187101991964934046277824279053058_lowmask_2.25.222182488376762395091213824095766275475.nii E:\data\CDor_3\mammo\Jordana_CEM\Patient_001\2.25.50003046908655299155646025163908180623_highmask_2.25.222182488376762395091213824095766275475.nii"
// by keesh (keesh@ieee.org)

// Linear rescales an image to [0,1] in place
function linearIntensityScale(imageTitle) {
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


function applyBreastPeripheralEqualization(input, output, filename, low_energy_mask, high_energy_mask) {
	//const
	resultName="_result";
	maskName="_mask";
	resultSuffix=".nii";
	
	// set up
	print("Processing file: " + input + filename);
	open(input + filename); 
	dotIndex = lastIndexOf(filename, ".");
	title = substring(filename, 0, dotIndex);	
	// Invert NII image to get an attentuation image
	run("Invert");
	run("Duplicate...", "title=I1");
	run("Duplicate...", "title=I2");
	run("Duplicate...", "title=I3");
	run("Duplicate...", "title=I1_THRESH");

	// open and combine masks
	print(low_energy_mask);
	open(low_energy_mask);
	title_low = getTitle();
	open(high_energy_mask);
	title_high = getTitle();
	imageCalculator("OR create", title_high, title_low);
	subtract_prefix = "Result of ";
	selectWindow(subtract_prefix + title_high);
	run("Duplicate...", "title=M1");
	run("Duplicate...", "title=M1_DBG");
	selectImage("M1_DBG");
	run("Multiply...", "value=255.000");  // for viz
	selectImage("M1");
	rename("S");
	// save mask
	outputFile = output + title + maskName + resultSuffix;
	run("NIfTI-1", "save=["+outputFile+"]");
	print("Processed: " + outputFile);

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
	linearIntensityScale("M");

	// M ^ 0.75
	run("Gamma...", "value=0.75");
	rename("M_75");

	// I / (M ^ 0.75)  
	selectImage("I3");
	run("32-bit");
	imageCalculator("Divide create 32-bit", "I3","M_75");

	//Output
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
args_array = split(args, "");
if (args_array.length==1 && args_array[0]=="--version") {
	print("0.0.1");
	exit();
}
input_output  = args_array[0];

// OPTIMIZE ME into one loop if this dir. case ever goes to production
// Step 1: Record base filenames of input NII images.
if (File.isDirectory(input_output)) {
	list = getFileList(input_output);
	input_output = input_output + File.separator;
	base_fnames = newArray();
	low_masks = newArray();
	high_masks = newArray();
	for (i = 0; i < list.length; i++) {
		if( File.isDirectory(input_output + list[i]) ) {
			continue;
		}
		if( endsWith(list[i], ".dcm") ){
			continue;
		}
		if( endsWith(list[i], ".png") ){
			continue;
		}
		// skip previous resultant mask images
		if( list[i].contains("_mask") ){
			continue;
		}
		if( list[i].contains("_lowmask_") ){
			low_masks = Array.concat(low_masks, list[i]);	
			continue;
		}
		if( list[i].contains("_highmask_") ){
			high_masks = Array.concat(high_masks, list[i]);	
			continue;
		}
		if( list[i].contains("result") ){
			continue;
		}
		base_fnames = Array.concat(base_fnames, list[i]);	
	}  // for i
	
	// Step 2: form lists of low and high complete filenames.
	for (i = 0; i < base_fnames.length; i++) {
		nii_base = base_fnames[i];

		// TODO-- How to get uid of nii_base (NII) ?
		// Need another pass tosave series UID for base_fnames[i]
		low_mask = "<fake_low_mask>";
		high_mask = "<fake_high_mask>";
		// assuming low masks is the same size as high masks
		for (j = 0; j < low_masks.length; j++) {
			if( low_masks[j].contains(uid) ){
				low_mask = low_masks[j];
			}
			if( high_masks[j].contains(uid) ){
				high_mask = high_masks[j];
			}
		}  // for j
		print("Calling PE: " + nii_base + " " + low_mask + " " + high_mask + "\n");
		break;
		// applyBreastPeripheralEqualization(input_output, input_output, nii_base, input_output+low_mask, input_output+high_mask);
	}  // for i
}
else if (File.exists(input_output)) {
	file_base = File.getName(input_output);
	input_output = File.getDirectory(input_output);
	low_obj_mask = args_array[1];  // optional masks
	high_obj_mask = args_array[2];
	applyBreastPeripheralEqualization(input_output, input_output, file_base, low_obj_mask, high_obj_mask);
}
else{
	print("Invalid input file or directory: " + input_output);
	exit();
}
setBatchMode(false); 
print("fin")