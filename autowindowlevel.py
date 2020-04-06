# Python  script to apply auto window/level to a NIFTI format file.
# Python 3.6.3, , numpy 1.17.2
# nibabel 2.5.0
# Translated from  AImageT<T>::AutoWindowLevel
import os
import sys
from pathlib import Path

import argparse

import numpy as np

import nibabel as nib
import nibabel.orientations as orientations

import glob

import ctypes
lib = None
if os.name != 'nt':   # 'posix', 'nt', 'java'
    lib = ctypes.cdll.LoadLibrary('./libautowindowlevel.so')
else:
    lib = ctypes.cdll.LoadLibrary('./libautowindowlevel.dll')

#globals for now
IMG_DTYPE = np.uin16  # Unsigned integer (0 to 65535)
# MIS_DTYPE = np.int16  # Integer (-32768 to 32767) C signed short




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

    return proxy_img, hdr, num_images

# img_reorient is the orig input NIFTI image in DICOM LPS
def write_nifti_mask(img, outputdirectory, base_fname, filepattern = ".nii"):
    filename = outputdirectory + os.path.sep + base_fname + "_mask1" + filepattern
    new_header = header = img_reorient.header.copy()
    new_header.set_slope_inter(1, 0)  # no scaling
    new_header['cal_min'] = np.min(mask_data)
    new_header['cal_max'] = np.max(mask_data)
    new_header['bitpix'] = 16
    new_header['descrip'] = "NIfti mask volume from Caffe 1.0"

    mask2 = np.zeros(img_reorient.shape, MASK_DTYPE)
    mask2[..., 0] = mask_data  # Add a 4th dim for Nifti, not sure if last dim is number of channels?
    nifti_mask_img = nib.nifti1.Nifti1Image(mask2, img_reorient.affine, header=new_header)

    # Need to xform numpy from supposed DICOM LPS to NIFTI original orientation (i.e. LAS, RAS, etc.)
    orients = orientations.axcodes2ornt(axcodes, nifti_in_codes_labels[axcodes])
    mask_reorient = nifti_mask_img.as_reoriented(orients)
    nib.save(mask_reorient, filename)


def get_image_slice(img, slice_no, load_as_dicom):
    if load_as_dicom:
        return img[..., slice_no]
    else:
        return img.dataobj[..., slice_no, 0]

""" Image Stats / Display"""
def stat(array):
    print('min: ' + str(np.min(array)) + ' max: ' + str(np.max(array)) + ' median: ' + str(np.median(array)) + ' avg: ' + str(np.mean(array)))

def perform_autowindowlevel(input_nifti_file):
    """ Read Test Data """
    img, hdr, num_images = read_nifti_series(input_nifti_file)

    # If we apply auto WL convert back to np 16 bit (signed/unsigned) based on image data type read in (make sure that we are still in the 16-bit range after b/m)
    img_slc  = img_slc.astype(MIS_DTYPE)  # np.int16
    (rows, cols) = img_slc.shape
    width = ctypes.c_int(cols)
    height = ctypes.c_int(rows)
    HasPadding = ctypes.c_bool(False)
    PaddingValue = ctypes.c_int(0)
    Slope = ctypes.c_double(m)
    Intercept = ctypes.c_double(b)
    c_short_p = ctypes.POINTER(ctypes.c_short)
    data = img_slc.ctypes.data_as(c_short_p)
    Window = ctypes.c_double()
    Level = ctypes.c_double()
    lib.AutoWindowLevel(data, width, height, Intercept, Slope, HasPadding, PaddingValue, ctypes.byref(Window), ctypes.byref(Level))
    win = Window.value
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
    ConstMaskDims = (num_rows, num_cols, num_images)
    mask_data_array = np.zeros(ConstMaskDims, dtype=MASK_DTYPE)
    mask_data_array[..., slice_no] = mask1
    print("Processed slice: " + str(slice_no+1) + " of " + str(num_images))

    nifti_base = Path(input_dir_file).resolve().stem
    write_nifti_mask(img, axcodes, mask_data_array, results_dir, nifti_base)

    print("Caffe liver inference COMPLETE.")

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
