# BADPIXUPDATE finds ixels corrected more than nrepeats times by XNZAP or XZAP
# and adds them to the bad pixel mask file. 

procedure badpixupdate (inlist, nrepeats, bpmask)

# Badpixupdate uses the files and imaccess CL biltins. It also uses the
# imcombine, imarith, minmax, imexpr, imstatistics, and imdelete tasks.

string  inlist		{prompt="List of mask images"}
int	nrepeats	{3, min=1, prompt="Threshold for repeated zaps"}
string	bpmask		{prompt="Bad pixel mask file"}

begin

	int nrep, nthresh, nim, nzap
	string ilist,  badp

# Get query parameters

	ilist = inlist
	nrep = nrepeats
	badp = bpmask

# Initialize.

	nthresh = nrep - 1

# Sum mask images from xzap to get list of zapped pixels.

	if (imaccess ("_cr_sum")) imdelete ("_cr_sum", ver-)
	files (ilist, sort-) | count | scan (nim)
        imcombine (ilist, "_cr_sum", headers="", bpmasks="", rejmasks="",
	    nrejmasks="", expmasks="", sigmas="", logfile="", comb="average",
	    reject="none", project-, outtype="real", outlimits="",
	    offsets="none", masktype="none", maskvalue=0.0 ,blank=0.,
	    scale="none", zero="none", weight="none", statsec="", expname="",
	    lthresh=INDEF, hthresh=INDEF, nlow=1, nhi=1, nkeep=1, mclip+,
	    lsigma=3.0, hsigma=3.0, rdnoise="0.0", gain="1.0", snoise="0.0",
            sigscale=0.1, pclip=-0.5, grow=0)

# Normalize the image since imcombine does not sum and imsum cannot deal
# with the number of files.

        imarith ("" // nim, "*", "_cr_sum","_cr_sum", title="", divzero=0.,
            hparams="", pixtype="real", calctype="real", ver-, noact-)


# If maximum greater than threshold, update bad pixel mask.

	minmax ("_cr_sum", force+, update-, ver-)
	if (minmax.maxval > nthresh) {
	    print ("Updating bad pixel map ", badp)
	    if (imaccess ("_jbadpix.pl")) imdelete ("_jbadpix.pl", ver-)
	    imexpr ("nint(a) > b ? 0 : 1", "_jbadpix.pl", "_cr_sum",
	        "" // nthresh, dims="auto", intype="auto", outtype="int",
		ref="auto", bwidth=0, btype="nearest", bpixval=0.0,
		rangecheck=yes, verbose=no, exprdb="none")
	    imstat ("_jbadpix.pl", fields="npix", lower=0, upper=0,
	        nclip=0, lsigma=3.0, usigma=3.0, format-, cache-) |
	        scan (nzap)
	    print ("    Adding ", nzap, " pixels to mask ", badp)
	    imarith ("_jbadpix.pl", "*", badp, badp, title="", divzero=0.0,
	        hparams="", pixtype="", calctype="", verbose-, noact-)
	    imdelete ("_jbadpix.pl", ver-)
	}

	imdelete ("_cr_sum", ver-)

end
