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

if (File.isDirectory(input_output)) {
	list = getFileList(input_output);
	input_output = input_output + File.separator;

	low_series_inst_uid = newArray();
	low_base_fname = newArray();

	// Process all low energy images first and record the following info
	// SeriesInstanceUID  (0020,000e) => low energy base filenamne
	for (i = 0; i < list.length; i++) {
		if( File.isDirectory(input_output + list[i]) ) {
			print("Skipping iternal directory: " + list[i]);
			continue;
		}
		//skip non nii files
		//process only mask files
		open(input_output + list[i]); 
		is_high = isHighEnergy();
		uid = getTag("0020,000E");
		dotIndex = lastIndexOf(list[i], ".");
		title = substring(list[i], 0, dotIndex);
		close();
		if ( ! is_high ){
			low_series_inst_uid = Array.concat(low_series_inst_uid, uid);
			low_base_fname = Array.concat(low_base_fname, title);	
			applyBreastPeripheralEqualization(input_output, input_output, list[i], obj_mask_exec, low_series_inst_uid, low_base_fname, 0);
		}

		// We use the low energy mask if it is aviable, as the high energy image is very faint on the breast periphery
		// 2.25.99203722366699835862900662085933500392_mask.nii
		found_match = 0;
		for (i = 0; i < low_series_inst_uid.length; i++) {
			if( low_series_inst_uid[i] == current_uid ){
				outputFile = output + low_base_fname[i] + resultName + resultSuffix;
    			print("Using low mask: " + low_base_fname[i] + " for high energy image:" + title);
    			found_match = 1;
    			break;
			}
		}
		if ( ! found_match ){
			print("No matching series UID for high energy image:" + title + " skipping.");	
			return;
		}
		
	}  // for i

	print("processed all low images: ");
	Array.print(low_series_inst_uid);
	Array.print(low_base_fname);

	// Process all the high energy images passing in the above data struct 
	for (i = 0; i < list.length; i++) {
		open(input_output + list[i]); 
		is_high = isHighEnergy();
		uid = getTag("0020,000E");
		close();
		if ( is_high ){
			applyBreastPeripheralEqualization(input_output, input_output, list[i], obj_mask_exec, low_series_inst_uid, low_base_fname, 1);
		}
	}  // for i
	setBatchMode(false); 
	print("fin");
	exit();
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