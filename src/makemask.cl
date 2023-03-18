# MAKEMASK creatas object masks for input images using median filtering
# techniques. 

procedure makemask (inlist, outlist)

# Image is sky subtracted, either using a constant value, or optionally by
# median filtering the image on a specified spatial scale and subtracting
# filtered image. If the desired filtering scale is large, the user may want
# to first subsample the image to a smaller size before filtering in order
# to speed up the calculation -- the resulting sky frame is then block
# replicated back up to the original image size before subtracting.
#
# After sky subtraction, a threshold is applied to the image after optional
# boxcar smoothing.  The threshold may be specified in terms of a number of
# sky sigma above the median sky level as measured using iterative sigma
# rejection, or as a specified constant number of ADU above the sky level. The
# resulting thresholded image is turned into a mask with "sky" set to 0 and
# "objects" set to 1.  The user may "grow" additional rings of pixels around
# masked regions to increase their area.
#
# Finally, the resulting mask may optionally be recorded in the input image
# header using the keyword BPM. The user may in fact create a mask from one
# input image and add it into the header of another by specifying different
# lists for inlist and hinlist.
#
# Calls the xdimsum ITERSTAT task.
#
# Also calls the sections, blkavg, minmax, fmedian, blkrep, imgets, imcopy,
# imarith, boxcar, imreplace, hedit, imdelete, and delete tasks.
#
# Creates temporary images of the form _ftemp, fwtemp, _blktemp, and  _mtemp

string	inlist		{prompt="The input images used to compute the masks"}
string	outlist		{prompt="The output masks"}
string	hinlist		{"",prompt="The list of images to add BPM keywords to"}
int	subsample	{1,min=0,prompt="Block averaging factor before median filtering"}
bool	checklimits 	{yes,prompt="Check data limits before filtering?"}
real	zmin		{-32767.,prompt="Minimum data value for fmedian"}
real	zmax		{32767.,prompt="Maximum data value for fmedian"}
int	filtsize	{15,min=0,prompt="Median filter size for local sky evaluation"}
int	nsmooth		{3,min=0,prompt="Boxcar smoothing size before thresholding"}
string	statsec		{"",prompt="Image region for computing sky statistics"}
real	nsigrej		{3.0, prompt="The nsigma sky statistics rejection limit"}
int	maxiter		{20, prompt="The maximum number of sky statistics iterations"}
string	threshtype	{"nsigma",enum="nsigma|constant",
				prompt="Thresholding type:  nsigma or constant"}
real	nsigthresh	{2.,prompt="Threshold for masking in sky sigma"}
real	constthresh	{0.,prompt="Constant threshold above sky for masking"}
bool	negthresh	{no,prompt="Set negative as well as positive thresholds ?"}
int	ngrow		{0,min=0,prompt="Half-width of box to grow around masked objects"}
bool	verbose		{no,prompt="Verbose output?"}

struct	*imglist
struct	*outimglist
struct	*hdrimglist

begin

real	thresh, nthresh, dmin, dmax, realsize
int	nin, nout, nbox, narea, ix,iy
string	inl, onl, infile, infile2, outfile, img, img2, outimg, workimg
string	cutsec, ext

# Get query parameters.

	inl = inlist
	onl = outlist

# Expand input and output file list.

	infile =  mktemp ("tmp$makemask")
	sections (inl, option="fullname", >infile)
	nin = sections.nimages

	outfile =  mktemp ("tmp$makemask")
	sections (onl, option="fullname", >outfile)
	nout = sections.nimages

	if (nin != nout) {
	    print ("The input and output image lists are not the same size")
	    delete (infile, ver-)
	    delete (outfile, ver-)
	    return
	}

# If parameter hinlist != "", update the image headers with bad pixel list.

	if (hinlist != "") {
	    infile2 =  mktemp ("tmp$makemask")
	    sections (hinlist, option="fullname", >infile2)
	    hdrimglist = infile2
	}


# The boxcar smoothing scale must be an odd number.

	if (nsmooth > 0) {
	    if (2 * int (nsmooth / 2) == nsmooth) {
		print ("Error: the parameter nsmooth must be an odd number")
	        delete (infile, ver-)
	        delete (outfile, ver-)
		if (hinlist != "") delete (infile2, verify-)
		return
	    }
	}
		
# Notify user of effective median filter scale.

	if (subsample > 1 && filtsize > 0) {
	    realsize = subsample * filtsize
	    if (verbose) {
	        print ("The effective median filter scale is ", realsize)
	    }
	}

# Size for boxcar smoothing in growing stage.

	nbox = (2 * ngrow + 1)
	narea = nbox * nbox


# Loop through input files.

	imglist = infile
	outimglist = outfile
	while (fscan (imglist, img) != EOF && fscan (outimglist,
	    outimg) != EOF) {

	    if (! imaccess (img)) {
		print ("The input image ", img, " does not exist")
		next
	    }

# Strip extension off filename if present.

	    fileroot (img, validim+)
	    img = fileroot.root
	    ext = fileroot.extension
	    if (ext != "") ext = "." // ext

	    fileroot (outimg, validim+)
	    outimg = fileroot.root // ".pl"
	    if (imaccess (outimg)) {
		print ("The output mask ", outimg, " already exists")
		next
	    }

	    if (verbose) print ("Working on image ", img)
	    if (verbose) print ("    Subtracting local sky")

# If filtsize > 0, median filter image to produce local sky, then subtract
# that from the image.

	    if (imaccess ("_mtemp")) imdelete ("_mtemp", verify-)
	    if (filtsize > 0) {

# If subsample > 1, block average input image to smaller size.

	        if (subsample > 1) {
		    if (verbose) print ("    Block averaging")
		    if (imaccess ("_blktemp")) imdelete ("_blktemp", verify-)
		    blkavg (img // ext, "_blktemp", subsample, subsample,
		        option="average")
		    workimg = "_blktemp"
		} else {
		    workimg = img
		}

# First, check limits of data range.  Wildly large (positive or negative)
# data values will screw up fmedian calculation unless checklimits = yes and
# zmin and zmax are set to appropriate values, e.g. zmin=-32768, zmax=32767.
# Note that the old fmedian bug which occurred if zmin=hmin and zmax=hmax has
# been fixed in IRAF version 2.10.1.

		if (verbose) print ("    Median filtering sky")
		if (checklimits) {
		    minmax (workimg, force+, update+, ve-)
		    if (verbose) print("    Data minimum = ", minmax.minval,
			" maximum = ", minmax.maxval)
		    if (minmax.minval < zmin || minmax.maxval > zmax) {
		        if (minmax.minval < zmin) {
			    dmin = zmin
		        } else { 
			    dmin = minmax.minval
		        }
		        if (minmax.maxval > zmax) {
			    dmax = zmax
		        } else { 
			    dmax = minmax.maxval
		        }
		        if (verbose) {
		            print ("    Truncating data range ",
			        dmin," to ",dmax)
		        }
		        if (imaccess ("_fwtemp")) imdelete ("_fwtemp", verify-)
		        fmedian (workimg, "_fwtemp", filtsize, filtsize,
			    hmin=-32768, hmax=32767, zmin=dmin, zmax=dmax,
			    zloreject=INDEF, zloreject=INDEF, unmap+,
			    boundary="nearest", constant=0.0, verbose-)
		    } else {
		        fmedian (workimg, "_fwtemp", filtsize, filtsize,
			    hmin=-32768, hmax=32767, zmin=INDEF, zmax=INDEF,
			    zloreject=INDEF, zhireject=INDEF, unmap+,
		            boundary="nearest", constant=0.0, verbose-)
		    }
		} else {
		    fmedian (workimg, "_fwtemp", filtsize, filtsize,
			hmin=-32768, hmax=32767, zmin=INDEF, zmax=INDEF,
			zloreject=INDEF, zhireject=INDEF, unmap+,
		        boundary="nearest", constant=0.0, verbose-)
		}

# If we have block averaged, block replicate median filtered image back to
# original size.
		if (subsample > 1) {
		    if (verbose) print ("    Block reproducing")
		    if (imaccess ("_ftemp")) imdelete ("_ftemp", verify-)
		    blkrep ("_fwtemp", "_ftemp", subsample, subsample)
		    imgets (img // ext, "i_naxis1")
		    ix = int (imgets.value)
		    imgets (img // ext, "i_naxis2")
		    iy = int (imgets.value)
		    cutsec = "[1:" // ix // ",1:" // iy // "]"
		    imcopy ("_ftemp" // cutsec, "_ftemp", ver-)
	            imarith (img // ext, "-", "_ftemp", "_mtemp", title="",
		        divzero=0.0, hparams="", pixtype="", calctype="",
		        verbose-, noact-)
		} else {
	            imarith (img // ext, "-", "_fwtemp", "_mtemp", title="",
		        divzero=0.0, hparams="", pixtype="", calctype="",
		        verbose-, noact-)
		}

	    } else {

# ...or, just copy the image to a working mask frame.

	        imcopy (img // ext, "_mtemp", verbose-)

	    }

# Calculate image statistics to determine median sky level and RMS noise.

	    if (verbose) print ("    Computing sky statistics")
	    iterstat ("_mtemp", statsec=statsec, nsigrej=nsigrej,
	        maxiter=maxiter, lower=INDEF, upper=INDEF, show-)
	    if (verbose) {
		print ("    Mean=", iterstat.imean, " Rms=", iterstat.isigma,
		    " Med=", iterstat.imedian, " Mode=", iterstat.imode)
	    }

# Smoothing image before thresholding.

	    if (nsmooth > 0) {
		if (verbose) {
		    print ("    Smoothing image before thresholding")
		}
		boxcar ("_mtemp", "_mtemp", nsmooth, nsmooth,
		    boundary="nearest", constant=0.0)
	    }

# Calculate threshold.

	    if (threshtype == "constant") {
		thresh = iterstat.imedian + constthresh
		if (negthresh)
		    nthresh = iterstat.imedian - constthresh
		else
		    nthresh = -1.0e37
	    } else {
		if (nsmooth > 0) {
		    thresh = iterstat.imedian + nsigthresh * iterstat.isigma /
			nsmooth
		    if (negthresh)
		        nthresh = iterstat.imedian - nsigthresh *
			    iterstat.isigma / nsmooth
		    else
		        nthresh = -1.0e37
		} else {
		    thresh = iterstat.imedian + nsigthresh * iterstat.isigma
		    if (negthresh)
		        nthresh = iterstat.imedian - nsigthresh *
			    iterstat.isigma
		    else
		        nthresh = -1.0e37
		}
	    }
	    if (verbose)
	        print ("    Thresholding image at level ",thresh)

# Apply threshold to image, setting "objects" to 1 and "sky" to 0. The order
# of the imreplace statments must be different if threshold is greater  than
# or less than 1.

	    if (verbose) {
	        print ("    Saving mask as ", outimg)
	    }

# If desired, grow rings around masked objects. Rings are only grown around
# positive objects.

	    if (ngrow > 0) {
                imexpr ("a > b ? 1 : 0", outimg, "_mtemp", "" // thresh,
	            dims="auto", intype="auto", outtype="int", refim="auto",
		    rangecheck=yes, bwidth=0, btype="nearest", bpixval=0.0,
		    exprdb="none", verbose-)
		if (verbose) print ("    Growing rings around masked objects")
		imarith (outimg, "*", narea, outimg, title="", divzero=0.0,
		    hparams="", pixtype="", calctype="", verbose-, noact-)
		boxcar (outimg, outimg, nbox, nbox, boundary="nearest",
		    constant=0.0)
		imreplace (outimg, 1, lower=1, upper=INDEF, radius=0.0)
		if (negthresh) {
                    imexpr ("a < b ? 1 : 0", "_mmtemp", "_mtemp", "" // nthresh,
	                dims="auto", intype="auto", outtype="int", refim="auto",
		        rangecheck=yes, bwidth=0, btype="nearest", bpixval=0.0,
			exprdb="none", verbose-)
		    imarith (outimg, "+", "_mmtemp", outimg, title="",
		        divzero=0.0, hparams="", pixtype="", calctype="",
			verbose-, noact-)
		    imreplace (outimg, 1, lower=1, upper=INDEF, radius=0.0)
		    imdelete ("_mmtemp", verify-)
		}
	    } else {
                imexpr ("a > b || a < c ? 1 : 0", outimg, "_mtemp",
		    "" // thresh, "" // nthresh, dims="auto", intype="auto",
		    outtype="int", refim="auto", rangecheck=yes, bwidth=0,
		    btype="nearest", bpixval=0.0, exprdb="none", verbose-)
	    }

# Record mask name into BPM keyword in image header of files specified 
# by hdrimglist.

	    if (hinlist != "") {
		if (fscan(hdrimglist, img2) != EOF) {
		    if (verbose) {
		        print ("    Recording pixel mask in image ", img2)
		    }
		    hedit (img2, "BPM", outimg, add+, ver-, update+)
	        }	
	    }

# Clean up.
	    if (filtsize > 0) {
		imdelete ("_fwtemp", verify-)
		if (subsample > 1 ) {
		    imdelete ("_blktemp", verify-)
		    imdelete ("_ftemp", verify-)
		}
	    }
	    imdelete ("_mtemp", verify-)

	}

	delete (infile, ver-)
	delete (outfile, ver-)
	if (hinlist != "") delete (infile2, ver-)
	imglist = ""
	outimglist = ""
	hdrimglist = ""
end
