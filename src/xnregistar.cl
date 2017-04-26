# Register the input images using imcombine.

procedure xnregistar (inlist, rmasks, output, expmap, sections)
	
string	inlist	 	{prompt="List of sky subtracted images, N and E shifts, and exposures"}
string	rmasks		{"", prompt="Input rection mask keyword or rejection mask list"}
string	output		{prompt="The output combined image name"}
string	expmap		{prompt="The output exposure map image"}
string	sections 	{"", prompt="The optional output sections file"}
string	sinlist 	{"", prompt="The list of image names to be written to sections "}

bool	blkrep		{yes, prompt="Use blkrep rather than magnify ?"}
real	mag 		{1, min=1, prompt="Block replication factor"}
bool	fractional	{no, prompt="Use fractional pixel shifts if mag = 1?"}
bool	pixin		{yes, prompt="Are input coords in ref object pixels?"}
bool	ab_sense 	{yes, prompt="Is A thru B counterclockwise?"}
real	xscale 		{1.0,prompt="X pixels per A coordinate unit"}
real	yscale 		{1.0,prompt="Y pixels per B coordinate unit"}
real	a2x_angle 	{0.0, prompt="Angle in degrees from A CCW to X"}

int	ncoavg      	{1, min=1, prompt="Number of coaverages per image"}
real	secpexp 	{1.0, prompt="Seconds per unit exposure time"}

real	y2n_angle 	{0.0, prompt="Angle in degrees from Y to N N thru E"}
bool	rotation 	{yes, prompt="Is N thru E CCW?"}


struct *imglist
struct *nimglist
struct *rimglist
struct *shimglist
struct *cmimglist

begin

real	trmag, taxrad, txscale, tyscale, a, b, newx, newy, navg
real	xmin, xmax, ymin, ymax, xfrac, yfrac, texp, mexp, fx1, et1
int	ip, nimages, nrin, nsin, tsign, ixmin, ixmax, iymin, iymax, ix, iy
int	ixdim, iydim, fx, fy
bool	verbose, first
string	tinlist, trmasks, toimg, texpmap, tsections, tsinlist, text
string	timg, nimg, rmskname, ntmpname, rtmpname, logfile
string	rlist, slist, ilist, bilist, tcmlist, olist, fxlist, etlist, shlist
string	cmlist
struct	theadline

# Get the query parameters

	tinlist = inlist
	count (tinlist) | scan (nimages)
	trmasks = rmasks

	toimg = output
	fileroot (toimg, validim+)
	toimg = fileroot.root
	texpmap = expmap
	fileroot (texpmap, validim+)
	texpmap = fileroot.root

	tsections = sections

# Get alternate image list.

	tsinlist = sinlist

# Create the rejection mask list.

	rlist = mktemp ("tmp$xnregistar")
	sections (trmasks, option="fullname", > rlist)
	nrin = sections.nimages

# Create the image names list.

	slist = mktemp ("tmp$xnregistar")
	sections (tsinlist, option="fullname", > slist)
	nsin = sections.nimages
	if (nsin > 0 && nsin != nimages) {
	    print ("The input and sections image lists are not the same size")
	    delete (rlist, verify-)
	    delete (slist, verify-)
	    return
	}

# Set verbose output.  For now this is a fixed parameter.
	verbose = NO
	if (verbose)
	    logfile = "STDOUT"
	else
	    logfile = ""
	

# Create the temporary imcombine input image, and block replicated input image
# list. Allos create a temporary combined mask list for use with those masks
# which need to be altered to account from the fractional pixel effects.

	ilist = mktemp ("tmp$xnregistar")
	bilist = mktemp ("tmp$xnregistar")
	cmlist = mktemp ("tmp$xnregistar")
	tcmlist = mktemp ("tmp$xnregistar")

# Create the imcombine offset list, flux conserve list, and exposure time
# list, and fractional pixel shift list.

	olist = mktemp ("tmp$xnregistar")
	fxlist = mktemp ("tmp$xnregistar")
	etlist = mktemp ("tmp$xnregistar")
	shlist = mktemp ("tmp$xnregistar")

# Set the magnification.

	if (blkrep) {
	    trmag = nint (mag)
	} else {
	    trmag = mag
	}

# Initialize geoemtry parameters.

	taxrad = a2x_angle * 3.1415926535 / 180.0
	if (ab_sense) {
	    tsign = 1
	} else {
	    tsign = -1
	}

# If input coords are measured in pixels with respect to reference object
# the scale is 1 but shifts are opposite sign of measured pixels. In this
# case a2x_angle is zero abd ab_sense is yes.

	txscale = xscale
	tyscale = yscale
	if (pixin) {
	    txscale = -1.0
	    tyscale = -1.0
	    taxrad = 0.0
	    tsign = 1
	}

# Delete existing output images.

	fileroot ("")
	text = fileroot.defextn
        if (imaccess (toimg//text)) {
            print ("Deleting existing output image ", toimg//text)
            imdelete (toimg//text, verify-)
        }
        if (imaccess (texpmap//text)) {
            print ("Deleting existing exposure image ", texpmap//text)
            imdelete (texpmap//text, verify-)
        }


# Delete existing sections file.

	if (tsections != "") {
	    if (access (tsections)) {
                print ("Deleting existing sections file ", tsections)
	        delete (tsections, verify-)
	    }
	}


# Compute the min and max shift values.

	imglist = tinlist
	first = yes
	while (fscan (imglist, timg, a, b) != EOF) {

# Compute the shifts.

	    newx = trmag * (txscale * a * cos (taxrad) +
	        tyscale * b * tsign * sin (taxrad))
	    newy = trmag * (tyscale * b * tsign * cos (taxrad) -
	        txscale * a * sin (taxrad))

# Determine the minimum and maximum shifts.

	    if (first) {
		xmin = newx
		xmax = newx
		ymin = newy
		ymax = newy
	    } else {
	        if (newx < xmin)
		    xmin = newx
	        if (newx > xmax)
		    xmax = newx
	        if (newy < ymin) 
		    ymin = newy
	        if (newy > ymax)
		    ymax = newy
	    }
	    first = no
	}

# Compute the minimum and maximum integer shift values.

	if (xmin != 0.0) {
	    ixmin = int (xmin + 0.5 * (xmin / abs (xmin)))
	} else {
	    ixmin = 0
	}
	if (xmax != 0.0) {
	    ixmax = int (xmax + 0.5 * (xmax / abs (xmax)))
	} else {
	    ixmax = 0
	}
	if (ymin != 0.0) {
	    iymin = int (ymin + 0.5 * (ymin / abs (ymin)))
	} else {
	    iymin = 0
	}
	if (ymax != 0.0) {
	    iymax = int (ymax + 0.5 * (ymax / abs (ymax)))
	} else {
	    iymax = 0
	}

		
# Prepare the imcombine input lists.

	imglist = tinlist
	nimglist = slist
	ip = 0
	while (fscan (imglist, timg, a, b, texp) != EOF) {

	    ip += 1

# Strip off extension if present and create the input image file name.

	    fileroot (timg, validim+)
	    timg = fileroot.root

# Create the input image list for imcombine.

	    print (timg, >> ilist)

# Create the block replicated input image list used if mag > 1.

	    print ("_blk_"//ip, >> bilist)

# Compute the shift.

	    newx = trmag * (txscale * a * cos (taxrad) +
	        tyscale * b * tsign * sin (taxrad))
	    newy = trmag * (tyscale * b * tsign * cos (taxrad) -
	        txscale * a * sin (taxrad))

# Determine the integer offsets for imcombine and store them in the
# offsets file.

	    if (newx != 0.0) {
	        ix = int (newx + 0.5 * (newx / abs (newx)))
	    } else {
	        ix = 0
	    }
	    if (newy != 0.0) {
	        iy = int (newy + 0.5 * (newy / abs (newy)))
	    } else {
	        iy = 0
	    }
	    print (ix, iy,  >> olist)
	    xfrac = newx - ix
	    yfrac = newy - iy
	    print (xfrac, yfrac, >> shlist)

# Write the sections file for the later maskdereg step.

	    if (tsections != "") {
	        ix = 1 + ix - ixmin
	        iy = 1 + iy - iymin
		hselect (timg, "i_naxis1", yes) | scan (ixdim)
		hselect (timg, "i_naxis2", yes) | scan (iydim)
		fx = ix + ixdim * trmag - 1
		fy = iy + iydim * trmag - 1
		if (fscan (nimglist, nimg) != EOF) {
		    fileroot (nimg, validim+)
		    nimg = fileroot.root
		    print (nimg, " ", ix, iy, fx, fy, >> tsections)
		} else {
		    print (timg, " ", ix, iy, fx, fy, >> tsections)
		}
	    }

# Set navg to 1 for now since the bundles feature is not being used.

	    navg = 1

# Compute the flux correction factor

	    mexp = (navg * ncoavg) / (trmag * trmag)
	    print (mexp, >> fxlist)
	    if (ip == 1)
		fx1 = mexp

# Compute the total exposure time. If the exposure time is less than or
# equal to 0 set it to 1 in the input list to imexamine for now. The image
# will be excluded from the imcombine step by setting the entire bad pixel
# mask to be zero.  Setting mep to zero produces problems in imcombine.

	    if (texp <= 0.0) {
		mexp = 1.0
	    } else {
	        mexp = texp * navg * ncoavg * secpexp
	    }
	    print (mexp, >> etlist)
	    if (ip == 1)
		et1 = mexp

	}

	imglist = tinlist
	rimglist = rlist
	shimglist = shlist

# Loop over the input image and rejection mask lists  copying name of
# the rejection mask into the BPM keyword. Do any necessary shifting in
# order to account for the fractional pixel shifts as necessary.


	ip = 0
	while (fscan (imglist, timg, a, b, texp) != EOF) {

	    ip += 1

# Strip off extension if present.

	    fileroot (timg, validim+)
	    timg = fileroot.root
	    print ("Checking mask for image: ", timg)

# Get the rejection mask.

	    if (trmasks == "") {
		rmskname = ""
	    } else {
		rmskname = ""
	        hselect (timg, trmasks, yes) | scan (rmskname)
	        if (rmskname != "") {
		    if (access (rmskname)) {
		        print ("    Using rejection mask file: ", rmskname)
		    } else {
		        print ("    Cannot find rejection mask file: ",
			    rmskname)
			rmskname = ""
		    }
	        } else if (fscan (rimglist, rmskname) != EOF) {
	            if (access (rmskname)) {
		        print ("    Using rejection mask file: ", rmskname)
		    } else if (nimages > nrin) {
		        rmskname = ""
		    } else {
		        print ("    Cannot find rejection mask file: ",
			    rmskname)
		        rmskname = ""
		    }
	        } else {
		    rmskname = ""
	        }
	    }


# Get fractional part of shift.

	    if (abs (trmag - 1.0) < 0.001 && fractional) {
	        if (fscan (shimglist, xfrac, yfrac) == EOF) {
		    xfrac = 0.0
		    yfrac = 0.0
		}
	    }

# Create a temporary mask name if necesary.

	    #if (rmskname != "") {
	        #ntmpname = "_msktmp"//ip//"."//rmskname
	        #if (imaccess (ntmpname))
		    #imdelete (ntmpname, verify-)
	        #rtmpname = "_rmsktmp"//ip//"."//rmskname
	        #if (imaccess (rtmpname))
		    #imdelete (rtmpname, verify-)
	    #} else {
	        ntmpname = "_msktmp."//ip//".pl"
	        if (imaccess (ntmpname))
		    imdelete (ntmpname, verify-)
		rtmpname = "_rmsktmp."//ip//".pl"
	        if (imaccess (rtmpname))
		    imdelete (rtmpname, verify-)
	    #}

# Set the BPM keyword.

	    # The exposure time is 0. Eliminate all data.
	    if (texp <= 0.0) {
		print ("    Warning the exposure time is <= 0 assume all bad")
		print ("    Creating temporary mask ", rtmpname)
		hselect (timg, "i_naxis1,i_naxis2", yes) | scan (ixdim, iydim)
		imexpr ("repl(a,b)", rtmpname, "0", ixdim,
		    dims=ixdim//","//iydim, intype="auto", outtype="auto",
		    ref="auto", bwidth=0, btype="nearest", bpixval=0.0,
		    rangecheck=yes, verbose=verbose, exprdb="none")
		print (rtmpname, >> cmlist)
		print (rtmpname, >> tcmlist)
	        hedit (timg, "BPM", add-, delete+, verify-, show-, update+)
	        hedit (timg, "BPM", rtmpname ,add+, delete-, verify-, show-,
		    update+)

	    # The rejection mask is undefined. Use all data.
	    } else if (rmskname == "") {
		print ("    Warning the mask is undefined assume all good")
		print ("    Creating temporary mask ", rtmpname)
		hselect (timg, "i_naxis1,i_naxis2", yes) | scan (ixdim, iydim)
		imexpr ("repl(a,b)", rtmpname, "1", ixdim,
	            dims=ixdim//","//iydim, intype="auto", outtype="auto",
		    ref="auto", bwidth=0, btype="nearest", bpixval=0.0,
		    rangecheck=yes, verbose=verbose, exprdb="none")
		print (rtmpname, >> cmlist)
		print (rtmpname, >> tcmlist)
	        hedit (timg, "BPM", add-, delete+, verify-, show-, update+)
	        hedit (timg, "BPM", rtmpname, ,add+, delete-, verify-, show-,
		    update+)

	    # The mask must be shifted a fractional pixel amount.
	    } else if (abs (trmag - 1.0) < 0.001 && fractional) {
		print ("    Shifting mask by ", xfrac, yfrac)
		imarith (rmskname, "*", "1000", ntmpname, title="",
		    divzero=0.0, hparams="", pixtype="", calctype="",
		    verbose=verbose, noact-)
		imshift (ntmpname, ntmpname, xfrac, yfrac, shifts_file="",
		    interp_type="linear", boundary_type="constant",
		    constant=0.0)
		imexpr ("a >= 999 ? 1 : 0", rtmpname, ntmpname, dims="auto",
		    intype="auto", outtype="auto", ref="auto", bwidth=0,
		    btype="nearest", bpixval=0.0, rangecheck=yes,
		    verbose=verbose, exprdb="none")
	        hedit (timg, "BPM", add-, delete+, verify-, show-, update+)
	        hedit (timg, "BPM", rtmpname, ,add+, delete-, verify-,
		    show-, update+)
		print (rtmpname, >> cmlist)
		print (rtmpname, >> tcmlist)
		imdelete (ntmpname, verify-)

	        # Magnification instead of block replication
		} else if (! blkrep) {
		    imcopy (rmskname, rtmpname, verbose=verbose)
		    hedit (timg, "BPM", add-, delete+, verify-, show-, update+)
		    hedit (timg, "BPM", rtmpname, ,add+, delete-, verify-,
			show-, update+)
		    print (rtmpname, >> cmlist)
		    print (rtmpname, >> tcmlist)

		# The mask is ok as is. No tmporary mask need be made.
		} else {
		    hedit (timg, "BPM", add-, delete+, verify-, show-, update+)
		    hedit (timg, "BPM", rmskname, ,add+, delete-, verify-,
			show-, update+)
		    print (rmskname, >> cmlist)
		}
	    }


	    # Combine the images.
	    if (abs (trmag - 1.0) < 0.001) {
		if (fractional) {
		    print ("Shifting the input images ...")
		    imshift ("@"//ilist, "@"//bilist, 0.0, 0.0,
			shifts_file=shlist, interp_type="linear",
			boundary_type="constant", constant=0.0)
		    print ("Shifting the exposure maps ...")
		    print ("Combining the input images ...")
		    imcombine ("@"//bilist, toimg, headers="", bpmasks="",
			rejmasks="", nrejmasks="", expmasks="", sigmas="",
			logfile=logfile, combine="sum", reject="none",
			project-, outtype="real", outlimits="",
			offsets=olist, masktype="goodvalue", maskvalue=1,
			blank=0.0, scale="@"//fxlist, zero="none",
			weight="none", statsec="", expname="",
			lthreshold=INDEF, hthreshold=INDEF, nlow=1,
			nhigh=1, mclip+, lsigma=3.0, hsigma=3.0,
			rdnoise="0.0", gain="1.0", snoise="0.0",
			sigscale=0.1, pclip=-0.5, grow=0.0)
		    print ("Combining the exposure time images ...")
		    imcombine ("@"//cmlist, texpmap, headers="", bpmasks="",
			rejmasks="", nrejmasks="", expmasks="", sigmas="",
			logfile=logfile, combine="sum", reject="none",
			project-, outtype="real", outlimits="",
			offsets=olist, masktype="none", maskvalue=0,
			blank=0.0, scale="@"//etlist, zero="none",
			weight="none", statsec="", expname="",
			lthreshold=INDEF, hthreshold=INDEF, nlow=1,
			nhigh=1, mclip+, lsigma=3.0, hsigma=3.0,
			rdnoise="0.0", gain="1.0", snoise="0.0",
			sigscale=0.1, pclip=-0.5, grow=0.0)
		} else {
		    print ("Combining the input images ...")
		    imcombine ("@"//ilist, toimg, headers="", bpmasks="",
			rejmasks="", nrejmasks="", expmasks="", sigmas="",
			logfile=logfile, combine="sum", reject="none",
			project-, outtype="real", outlimits="",
			offsets=olist, masktype="goodvalue", maskvalue=1,
			blank=0.0, scale="@"//fxlist, zero="none",
			weight="none", statsec="", expname="",
			lthreshold=INDEF, hthreshold=INDEF, nlow=1,
			nhigh=1, mclip+, lsigma=3.0, hsigma=3.0,
			rdnoise="0.0", gain="1.0", snoise="0.0",
			sigscale=0.1, pclip=-0.5, grow=0.0)
		    print ("Combining the exposure time images ...")
		    imcombine ("@"//cmlist, texpmap, headers="", bpmasks="",
			rejmasks="", nrejmasks="", expmasks="", sigmas="",
			logfile=logfile, combine="sum", reject="none",
			project-, outtype="real", outlimits="",
			offsets=olist, masktype="none", maskvalue=0,
			blank=0.0, scale="@"//etlist, zero="none",
			weight="none", statsec="", expname="",
			lthreshold=INDEF, hthreshold=INDEF, nlow=1,
			nhigh=1, mclip+, lsigma=3.0, hsigma=3.0,
			rdnoise="0.0", gain="1.0", snoise="0.0",
			sigscale=0.1, pclip=-0.5, grow=0.0)
		}
	    } else {
		imdelete ("@"//bilist, verify-, >& "dev$null")
		if (blkrep) {
		    print ("Block replicating the input images ...")
		    blkrep ("@"//ilist, "@"//bilist, nint(trmag),
			nint(trmag))
		    print ("Block replicating the exposure time images ...")
		    blkrep ("@"//cmlist, "@"//cmlist, nint(trmag),
			nint(trmag))
		} else {
		    print ("Magnifying the input images ...")
		    magnify ("@"//ilist, "@"//bilist, trmag, trmag,
			x1=INDEF, x2=INDEF, dx=INDEF, y1=INDEF, y2=INDEF,
			dy=INDEF, interpolation="linear", boundary="nearest",
			constant=0.0, fluxconserve-, logfile="")
		    print ("Magnifying the exposure time images ...")
		    imarith ("@"//cmlist, "*", "1000", "@"//cmlist,
			title="", divzero=0.0, hparams="", pixtype="",
			calctype="", verbose=verbose, noact-)
		    magnify ("@"//cmlist, "@"//cmlist, trmag, trmag,
			x1=INDEF, x2=INDEF, dx=INDEF, y1=INDEF, y2=INDEF,
			dy=INDEF, interpolation="linear", boundary="nearest",
			constant=0.0, fluxconserve-, logfile="")
		    cmimglist = cmlist
		    while (fscan (cmimglist, timg) != EOF) {
			imexpr ("a >= 999 ? 1 : 0", "_tmpname.pl", timg,
			    dims="auto", intype="auto", outtype="auto",
			    ref="auto", bwidth=0, btype="nearest",
			    bpixval=0.0, rangecheck=yes, verbose=verbose,
			    exprdb="none")
			imdelete (timg, verify-)
			imrename ("_tmpname.pl", timg, verbose=verbose)
		    }
		}
		print ("Combining the input images ...")
		imcombine ("@"//bilist, toimg, headers="", bpmasks="",
		    rejmasks="", nrejmasks="", expmasks="", sigmas="",
		    logfile=logfile, combine="sum", reject="none",
		    project-, outtype="real", outlimits="", offsets=olist,
		    masktype="goodvalue", maskvalue=1, blank=0.0,
		    scale="@"//fxlist, zero="none", weight="none", statsec="",
		    expname="", lthreshold=INDEF, hthreshold=INDEF, nlow=1,
		    nhigh=1, mclip+, lsigma=3.0, hsigma=3.0, rdnoise="0.0",
		    gain="1.0", snoise="0.0", sigscale=0.1, pclip=-0.5,
		    grow=0.0)
		print ("Combining the exposure time images ...")
		imcombine ("@"//cmlist, texpmap, headers="", bpmasks="",
		    rejmasks="", nrejmasks="", expmasks="", sigmas="",
		    logfile=logfile, combine="sum", reject="none",
		    project-, outtype="real", outlimits="", offsets=olist,
		    masktype="none", maskvalue=0, blank=0.0,
		    scale="@"//etlist, zero="none", weight="none",
		    statsec="", expname="", lthreshold=INDEF,
		    hthreshold=INDEF, nlow=1, nhigh=1, mclip+, lsigma=3.0,
		    hsigma=3.0, rdnoise="0.0", gain="1.0", snoise="0.0",
		    sigscale=0.1, pclip=-0.5, grow=0.0)
	    }

# Correct for the relative scaling to the first image.
	if (abs (fx1-1.) > 0.001)
	    imarith (toimg, "*", fx1, toimg, title="", divzero=0.,
		hparams="", pixtype="", calctype="", verbose=verbose,
		noact=no)
	if (abs (et1-1.) > 0.001)
	    imarith (texpmap, "*", et1, texpmap, title="", divzero=0.,
		hparams="", pixtype="", calctype="", verbose=verbose,
		noact=no)

# Divide output image sum by exposure map.

	imarith (toimg, "/", texpmap, toimg, title="", divzero=0.,
	    hparams="", pixtype="real", calctype="real", ver-, noact-)

# Orient these to N at top, E at left for iraf default

	orient (toimg, y2n_angle, rotation=rotation, invert-)
	orient (texpmap, y2n_angle, rotation=rotation, invert-)

# Remove the BPM keyword from the input images.

	imglist = tinlist
	while (fscan (imglist, timg) != EOF) {
	    hedit (timg, "BPM", add-, delete+, verify-, show-, update+)
	}

# Copy header information from first input frame into the final mosaic and 
# exposure map images.  Set mosaic exposure time to 1 second, delete exposure
# time info from exposure map, and reset image titles.  Add comment card about
# origin of header information.

	imglist = tinlist			# rewind imglist
	if (fscan (imglist, timg, a, b) != EOF) {
	    hselect (timg, "title", yes) | scan (theadline)
	    hedit (toimg, "exptime", "1", add+, delete-, verify-, show-,
	        update+)
	    hedit (toimg, "title", "Final combined image: "//theadline,
	        add+, delete-, verify-, show-, update+)
	    hedit (texpmap, "title", "Exposure time map: "//theadline,
	        add+, delete-, verify-, show-, update+)
	    hedit (toimg,
	    "BPM,CRMASK,CROBJMAS,HOLES,MASKFIX,OBJMASK,REJMASK,SKYMED,SKYSUB",
	     add-, delete+, verify-, show-, update+)
            #addcomment (toimg, "Header data copied from file "//timg, ver-)
	}

# Cleanup.

	delete (olist, verify-)
	delete (fxlist, verify-)
	delete (etlist, verify-)
	delete (shlist, verify-)

	delete (ilist, verify-)
	if (access (tcmlist)) {
	    imdelete ("@"//tcmlist, verify-, >& "dev$null")
	    delete (tcmlist, verify-)
	}
	delete (cmlist, verify-)
	imdelete ("@"//bilist, verify-, >& "dev$null")
	delete (bilist, verify-)

	delete (rlist, verify-)
	delete (slist, verify-)

	imglist = ""
	nimglist = ""
	rimglist = ""
	shimglist = ""
	cmimglist = ""
end
