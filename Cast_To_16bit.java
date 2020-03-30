import ij.*;
import ij.process.*;
import ij.plugin.filter.*;
import ij.plugin.*;

// Ref. See https://imagej.nih.gov/ij/plugins/dither/Floyd_Steinberg_Dithering.java for a simple plugin model
public class Cast_To_16bit implements PlugIn {
	public void run(String arg) {
  		ImagePlus imp = IJ.getImage();
		if(imp.getType() != ImagePlus.GRAY32 ) {
			IJ.error("Cast_To_16bit only supports image type of GRAY32");
			return;
		}
  		
        ImageProcessor ip = imp.getProcessor();
        int width = imp.getWidth();
        int height = imp.getHeight();
  		float[] pixels32 = (float[])ip.getPixels();
        short[] pixels16 = new short[width*height];
        double value;
        for (int i=0,j=0; i<width*height; i++) {
        	value = pixels32[i];
            if (value<0.0) value = 0.0;
            if (value>65535.0) value = 65535.0;
            pixels16[i] = (short)(value+0.5);
        }
        ShortProcessor sp = new ShortProcessor(width, height, pixels16, ip.getColorModel());
        imp.setProcessor(null, sp);
	}
}