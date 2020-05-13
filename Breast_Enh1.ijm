// Image/J (Fiji) macro to implement Breast Peripheral Equalization
// Input is a directory containing DICOM format files or a single DICOM file.
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

function applyBreastPeripheralEqualization(input, output, filename) {
	// set up
	print("Processing file: " + input + filename);
	open(input + filename); 
	dotIndex = lastIndexOf(filename, ".");
	title = substring(filename, 0, dotIndex);
	run("Duplicate...", "title=I1");
	run("Duplicate...", "title=I2");
	run("Duplicate...", "title=I3");
	
	// Segmentation by thresholding (could probably consolidate following steps)
	// bgnd=0, fgnd=1
	selectImage("I1");
	// 1. Mean, 2. RenyiEntropy, 3. Otsu
	run("Auto Threshold", "method=Mean white");  
	run("Invert");
	run("Divide...", "value=255.000");
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
	
	//Clean up
	close("*");  // Closes all images 
}  // apply...

//Using batch mode causes weird Windows focus errors on second pass after run LowpassFilters if the class is not compiled.
setBatchMode(true);
input_output = getArgument();
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

for (i = 0; i < list.length; i++)
	// input dir, output dir, filename
	applyBreastPeripheralEqualization(input_output, input_output, list[i]);
setBatchMode(false); 
print("fin")