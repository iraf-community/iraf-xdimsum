# Create the master image masks used by xslm.

procedure mkmask (input, expmap, output, nthreshold)

# 
# Also calls the display, imexamine, minmax, imcopy, imreplace, imarith, and
# imdelete tasks.
#
# Creates temporary images called _zerotemp, _inormtemp, and  _normtemp.

string	input		{prompt="The input image used to make the  mask"}
string	expmap		{prompt="The input exposure map image"}
string	output		{prompt="The name of the output object mask"}
real	nthreshold	{prompt="Number of recommended thresholds for object detection"}
bool	negthresh	{no, prompt="Set negative as well as positive thresholds ?"}
string	statsec		{"", prompt="Image region for computing sky statistics"}
real	nsigrej		{3.0, prompt="The nsigma sky statistics rejection limit"}
int	maxiter		{20, prompt="The maximum number of sky statistics iterations"}
int	nsmooth		{3,min=0,prompt="Boxcar smoothing size before thresholding"}
int	subsample	{1,min=1,prompt="Block averaging factor before median filtering"}
int	filtsize	{15,min=1,prompt="Median filter size for local sky evaluation"}
int	ngrow		{0,min=0,prompt="Half-width of box to grow around masked objects"}
bool	interactive	{yes,prompt="Interactively examine normalized image?"}
real	threshold	{prompt="Cutoff threshold ",mode="q"}

begin
	real	th, recthresh, minval, maxval, maxexp, flagval
	string	img, texpmap, oimg, ext

# Get query parameter.

	img = input
	texpmap = expmap
	oimg = output 

# Strip extension off file name.

	fileroot (img, validim+)
	img = fileroot.root
	ext = fileroot.extension
	if (ext != "") ext = "." // ext
	fileroot (oimg, validim+)
	oimg = fileroot.root // ".pl"

# Normalize image to uniform pixel-to-pixel rms using square root of exposure
# map. Resulting frame is called _inormtemp. If the exposure map does not
# exist then no normalization is necessary and the statistics cab be computed
# directly.

	if (texpmap == "") {

	    iterstat (img // ext, statsec=statsec, nsigrej=nsigrej,
	        maxiter=maxiter, lower=INDEF, upper=INDEF, show-)

	} else {

	    sigmanorm (img // ext, texpmap, "_inormtemp")

# Set flag value at 1 DN below minimum pixel value in normalized image.

	    minmax ("_inormtemp", update-, ver-)
	    minval = minmax.minval
	    maxval = minmax.maxval
	    flagval = 2 * minval - maxval

# Identify regions with zero exposure time and exclude from sigma calculation
# by flagging them to the flagval and excluding them from the iterstat
# calculation.

	    imexpr ("a <= 0.0 ? b : 0.0", "_zerotemp", texpmap, "" // flagval,
	        dims="auto", intype="real", outtype="real", refim="auto",
	         rangecheck=yes, bwidth=0, btype="nearest", bpixval=0.0,
		 exprdb="none", verbose-)
	    imarith ("_inormtemp", "+", "_zerotemp", "_normtemp",
	        divzero=0.0, hparams="", pixtype="real", calctype="real",
		ver-, noact-)

	    iterstat ("_normtemp", statsec=statsec, nsigrej=nsigrej,
	        maxiter=maxiter, lower=minval, upper=INDEF, show-)

	    imdelete ("_zerotemp", ver-)
	    imdelete ("_normtemp", ver-)
	}

# Calculate rms of masked, normalized image with iterative sigma rejection.
# Recommended threshold (to be applied to boxcar smoothed data) is approx.
# 4.5/nsmooth x unsmoothed rms.

	recthresh = 4.5 / nsmooth * iterstat.isigma

# Optionally allow user to interactively examine the unsmoothed normalized
# image to set threshold for masking.

	if (interactive) {
	    print ("Recommended threshold level for mask is ", recthresh)
	    if (texpmap == "") {
	        imexamine (img // ext,
		    display="display(image='$1',frame=$2,zs+)")
	    } else {
	        imexamine ("_inormtemp",
	            display="display(image='$1',frame=$2,zs+)")
	    }
	    th = threshold
	} else {
	    print ("Setting threshold level for mask to ", nthreshold,  " * ",
	        "the recommended threshold ", recthresh)
	    th = nthreshold * recthresh
	}


# Create the mask.

	if (texpmap == "") {
	    makemask (img // ext, oimg, hinlist="", subsample=subsample,
	        filtsize=filtsize, nsmooth=nsmooth, statsec=statsec,
		nsigrej=nsigrej, maxiter=maxiter, threshtype="constant",
		nsigthresh=2.0, constthresh=th, negthresh=negthresh,
		ngrow=ngrow, checklimits+, zmin=-32767.0, zmax=32767.0, ver-)
	} else {
	    makemask ("_inormtemp", oimg, hinlist="", subsample=subsample,
	        filtsize=filtsize, nsmooth=nsmooth, statsec=statsec,
		nsigrej=nsigrej, maxiter=maxiter, threshtype="constant",
		nsigthresh=2.0, constthresh=th, negthresh=negthresh,
		ngrow=ngrow, checklimits+, zmin=-32767.0, zmax=32767.0, ver-)
	    imdelete ("_inormtemp", ver-)
	}

# Display original image and the mask.

	if (interactive) {
	      display (img // ext, 1)
	      display (oimg, 2, z1=0, z2=1, zsca-, zra-)
	}

end
