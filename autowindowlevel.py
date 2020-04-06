# Python  script to apply auto window/level to a NIFTI format file.
# Python 3.6.3, numpy 1.18.2
# nibabel 3.0.2
# Translated from MIS AImageT<T>::AutoWindowLevel
import os
import sys
from pathlib import Path
import argparse

import numpy as np
import nibabel as nib
import nibabel.orientations as orientations


import ctypes
lib = None
if os.name != 'nt':   # 'posix', 'nt', 'java'
    lib = ctypes.cdll.LoadLibrary('./libautowindowlevel.so')
else:
    lib = ctypes.cdll.LoadLibrary('./libautowindowlevel.dll')


def main(inpArgs):
    try:
        perform_autowindowlevel(os.path.abspath(inpArgs.input_nifti_file))
        sys.exit(0)
    except IOError as ioex:
        print("There was an IO error: " + str(ioex.strerror))
        sys.exit(1)
    except Exception as e:
        print("There was an unexpected error: " + str(e))
        sys.exit(1)


""" Image I/O  """
def read_nifti_series(filename):
    proxy_img = nib.load(filename)
    # less efficent get image data into memory all at once
    # image_data = proxy_img.get_fdata()

    hdr = proxy_img.header
    image_shape = hdr.get_data_shape()
    image_dim = len(image_shape)
    num_images = 1
    if image_dim >= 3:
        num_images = image_shape[2]

    return proxy_img, hdr, num_images, hdr.get_data_dtype()

# img_reorient is the orig input NIFTI image in DICOM LPS
def write_nifti_series(img, datatype, img_data_array, outputdirectory, base_fname, filepattern = ".nii"):
    filename = outputdirectory + os.path.sep + base_fname + "_awl" + filepattern
    new_header = header = img.header.copy()
    new_header.set_slope_inter(1, 0)  # no scaling
    new_header['cal_min'] = np.min(img_data_array)
    new_header['cal_max'] = np.max(img_data_array)
    new_header['bitpix'] = 16
    new_header['descrip'] = "NIfti suto window level volume"

    img2 = np.zeros(img.shape, datatype)
    img2[..., 0] = img_data_array,  # Add a 4th dim for Nifti, not sure if last dim is number of channels?
    nifti_img = nib.nifti1.Nifti1Image(img2, img.affine, header=new_header)
    nib.save(nifti_img, filename)


def get_image_slice(img, slice_no):
    return img.dataobj[..., slice_no, 0]

""" Image Stats / Display"""
def stat(array):
    print('min: ' + str(np.min(array)) + ' max: ' + str(np.max(array)) + ' median: ' + str(np.median(array)) + ' avg: ' + str(np.mean(array)))

def perform_autowindowlevel(input_nifti_file):
    img, hdr, num_images, datatype = read_nifti_series(input_nifti_file)
    img_data_array = None  # NIFTI only
    for slice_no in range(0, num_images):
        img_slc = get_image_slice(img, slice_no)

        # If we apply auto WL convert back to np 16 bit (signed/unsigned) based on image data type read in (make sure that we are still in the 16-bit range after b/m)
        (rows, cols) = img_slc.shape
        width = ctypes.c_int(cols)
        height = ctypes.c_int(rows)
        HasPadding = ctypes.c_bool(False)
        PaddingValue = ctypes.c_int(0)
        Slope = ctypes.c_double(1)
        Intercept = ctypes.c_double(0)

        if datatype == np.int16:
            c_short_p = ctypes.POINTER(ctypes.c_short)
            data = img_slc.ctypes.data_as(c_short_p)
        elif datatype == np.uint16:
            c_ushort_p = ctypes.POINTER(ctypes.c_ushort)
            data = img_slc.ctypes.data_as(c_ushort_p)
        else:
            raise NotImplementedError("Input image data type not supported: " + str(datatype))

        Window = ctypes.c_double()
        Level = ctypes.c_double()
        lib.AutoWindowLevel(data, width, height, Intercept, Slope, HasPadding, PaddingValue,
                            ctypes.byref(Window), ctypes.byref(Level))
        win = Window.valud
        lev = Level.value
        print("Auto W/L window = " + str(win) + ", level = " + str(lev))
        if win != 1:
            thresh_lo = float(lev) - 0.5 - float(win-1) / 2.0
            thresh_hi = float(lev) - 0.5 + float(win-1) / 2.0
            thresh_hi += 1.0  # +1 due to > sided test
            img_slc = np.clip(img_slc, int(thresh_lo), int(thresh_hi))
            print("MIS AWL Threshold: [" + str(thresh_lo) + "," + str(thresh_hi) + "]")
            stat(img_slc)

        # NIFTI create and fill mask array
        if slice_no == 0:
            ConstImgDims = (rows, cols, num_images)
            img_data_array = np.zeros(ConstImgDims, dtype=datatype)
            img_data_array[..., slice_no] = img_slc
        print("Processed slice: " + str(slice_no+1) + " of " + str(num_images))

        file_as_path = Path(input_nifti_file)
        nifti_base = file_as_path.resolve().stem
        write_nifti_series(img, datatype, img_data_array, file_as_path.parent, nifti_base)

    print("Auto window level COMPLETE.")


if __name__ == '__main__':
    '''
    This script runs auto window level on input NIFTI 16-bit images.
    '''
    parser = argparse.ArgumentParser(description='Auto window level on input images')
    parser.add_argument("-i", dest="input_nifti_file", help="The input NIfti1 format file (16-bit)")
    if len(sys.argv) < 3:
        print("python autowindowlevel.py -i <input_nifti_file>")
        parser.print_help()
        sys.exit(1)
    inpArgs = parser.parse_args()
    main(inpArgs)
