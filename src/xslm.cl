# Sky subtract a list of images  using a running mean frame, akin to a local
# sky flatfield. 
#
# Sky frames are scaled by their median values before combining. Medians are
# used because the data is unflattened. The image medians are computed with
# the iterstat or maskstat tasks depending on whether or not masking is
# enabled. The computed median is written into the SKYMED header keyword.
# If a SKYMED keyword already exists then the median is not recomputed unless
# the forcescale parameter is enabled.
#
# Boolean parameter premask determines if scaling of images by their medians
# excludes masked regions. For cases where variation due to  objects exceeds
# the residual flatfield variation in the input images, this parameter should
# be yes.  For dim objects and noticeable residual flatfield problems it should
# be no.  Note that even with premask=no imcombine will mask out pixels.
# Xslm runs quicker with premask=no


procedure xslm (inlist, omasks, nmean, outlist)

# Calls the xdimsum scripts xlist, iterstat, minv, maskstat, and addcomment.
#
# Also calls the tasks imstat, imcopy, imreplace, sections, delete, imgets
# hedit, imcombine, imarith, imdelete, and imexpr.

string	inlist	     {prompt="List of input images to be sky subtracted"}
string	omasks	     {"", prompt="The input object mask keyword or list"}
int	nmean        {min=1,prompt="Number of images to use to make sky frame"}
string 	outlist	     {".sub", prompt="The output sky subtracted images or suffix"}
string 	ssmasks      {".ssm", prompt="The output sky subtraction masks or suffix"}
string 	hmasks	     {".hom", prompt="The output holes masks or suffix"}

bool	forcescale  {no,  prompt="Force recalculation of input image medians ?"}
bool 	useomask    {yes, prompt="Use object masks to compute sky statistics ?"}
string	statsec	    {"", prompt="The sky statistics image section"}
real	nsigrej	    {3.0, prompt="The nsigma sky statistics rejection limit"}
int	maxiter	    {20, prompt="The maximum number of sky statistics iterations"}
int	nskymin     {3, min=0, prompt="The minimum number of frames to use for sky"}
int	nreject     {1, min=0, prompt="The number of high and low side pixels to reject"}

bool 	del_ssmasks {yes, prompt="Delete sky substraction masks on task termination ?"}
bool 	del_hmasks   {no, prompt="Delete holes masks on task termination ?"}

struct	*imglist
struct	*omskimglist
struct	*outimglist
struct	*ssmskimglist
struct	*hmskimglist

begin
	real	valmed, imcscale
	int	tnmean, nin, nomasks, nsmin, ip, nml, nmh, start, finish, nrej
	int 	nskyframes, maxcsky
	string	tomasks, outimlist, toutlist, imlist, omsklist, img, maskfile
	string	subimg, templist, ext, tssmasks, ssmsklist, ssmsk, thmasks
	string  hmsklist, hmsk
	bool	msk, skysub, scalecalc
	struct	theadline

# Make temporary files.

	imlist  = mktemp ("tmp$xslm") 
	omsklist  = mktemp ("tmp$xslm") 
	outimlist  = mktemp ("tmp$xslm") 
	ssmsklist  = mktemp ("tmp$xslm") 
	hmsklist  = mktemp ("tmp$xslm") 

# Get query parameters and initialize

	sections (inlist, option="fullname", > imlist)
	nin = sections.nimages
	tnmean = nmean

	tomasks = omasks
        sections (tomasks, option="fullname", > omsklist)
	nomasks = sections.nimages
	if (tomasks == "") {
	    msk = no
	    useomask = no
        } else if (nomasks > 0) {
            if (nomasks > 1 && nin != nomasks) {
                print ("Input and object mask image lists do not match")
		delete (imlist, ver-)
		delete (omsklist, ver-)
                return
            } else {
		msk = yes
            }
        } else {
	    msk = no
	    useomask =  no
        }

	toutlist = outlist
        if (substr (toutlist, 1, 1) == ".") {
            imglist = imlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // toutlist
                print (img, >> outimlist)
            }
        } else {
            sections (toutlist, option="fullname", > outimlist)
            if (nin != sections.nimages) {
                print ("Error: Input and cosmic ray image lists do not match")
                delete (imlist, ver-)
                delete (outimlist, ver-)
                delete (omsklist, ver-)
                return
            }
        }

	tssmasks = ssmasks
        if (substr (tssmasks, 1, 1) == ".") {
            imglist = outimlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tssmasks
                print (img, >> ssmsklist)
            }
        } else {
            sections (tssmasks, option="fullname", > ssmsklist)
            if (nin != sections.nimages) {
                print ("Error: Input and sky masks image lists do not match")
                delete (imlist, ver-)
                delete (outimlist, ver-)
                delete (omsklist, ver-)
                delete (ssmsklist, ver-)
                return
            }
        }

	thmasks = hmasks
        if (substr (thmasks, 1, 1) == ".") {
            imglist = outimlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // thmasks
                print (img, >> hmsklist)
            }
        } else {
            sections (thmasks, option="fullname", > hmsklist)
            if (nin != sections.nimages) {
                print ("Error: Input and holes mask image lists do not match")
                delete (imlist, ver-)
                delete (outimlist, ver-)
                delete (omsklist, ver-)
                delete (ssmsklist, ver-)
                delete (hmsklist, ver-)
                return
            }
        }

# Check the value of nskymin.

	if (nskymin > tnmean) {
	    print ("Parameter nskymin must be <= nmean")
	    delete (imlist, ver-)
            delete (outimlist, ver-)
	    delete (omsklist, ver-)
            delete (ssmsklist, ver-)
            delete (hmsklist, ver-)
	    return
	} else if (nskymin == 0) {
	    nsmin = tnmean
	} else {
	    nsmin = nskymin
	}

# Calculate the scaling factors for all frames. If we are using object masking
# first get the name of the object mask from the image header keyword OBJMASK
# and then insert this name into the keyword BPM for later use in imcombine.

	imglist = imlist
	omskimglist = omsklist
	skysub = no
	while (fscan (imglist, img) != EOF) {

# Determine whether or not to compute the scaling factor

	    scalecalc = forcescale
	    if (! forcescale) {
		templist = ""
		hselect (img, "SKYMED", yes) | scan (templist)
		if (templist == "") scalecalc = yes
	    }
	    if (scalecalc) {
	        print ("Calculating scaling for ", img)
	    }

# Determine the name of the mask file and store it in the image header.

	    if (msk) {
		maskfile = ""
		hselect (img, tomasks, yes) | scan (maskfile)
		if (maskfile != "") {
		    if (access (maskfile)) {
                        print ("    Using header object mask : ", maskfile)
		    } else {
			print ("    Cannot find object mask: ", maskfile)
    			maskfile = ""
		    }
		} else if (fscan (omskimglist, maskfile) != EOF) {
		    if (access (maskfile)) {
                        print ("    Using object mask : ", maskfile)
		    } else if (nin > nomasks) {
			maskfile = ""
		    } else {
			print ("    Cannot find object mask: ", maskfile)
			maskfile = ""
		    }
		} else {
		    maskfile = ""
		}
		if (maskfile != "") {
		    hedit (img, "BPM", maskfile, add+, delete-, verify-,
		        show-, update+)
		}
	    } else {
		maskfile = ""
	    }

# Calculate the median of the image. If useomask=yes use only unmasked pixels.
# Record this value into the image header with the card SKYMED. If SKYMED card
# already exists in the header, do not recalculate unless the parameter
# forcescale=yes.

	    if (scalecalc) {
	        #print ("Calculating scaling for ", img)
		if (msk && useomask) {
		    maskstat (img, maskfile, 0.0, statsec=statsec, lower=INDEF,
		        upper=INDEF, iterstat+, nsigrej=nsigrej,
			maxiter=maxiter, show-)
		    imcscale = 1.0 / maskstat.median
		    print ("    Setting scaling factor to 1 / ",
		        maskstat.median)
		} else {
		    iterstat (img, statsec=statsec, nsigrej=nsigrej,
		        maxiter=maxiter, lower=INDEF, upper=INDEF, show-)
		    imcscale = 1.0 / iterstat.imedian
		    print ("    Setting scaling factor to 1 / ",
		        iterstat.imedian)
		}
		skysub = yes
		hedit (img, "SKYMED", imcscale, add+, delete-, verify-,
		    show-, update+)
	    }

	}

# Initialize and check parameter values.

	ip=0
	if (tnmean > nin) {
	    tnmean = nin - 1
	    print("Xslm parameter nmean too big resetting t0: ", tnmean)
	}
	if (tnmean < 1) {
	    print("Nmedian is too small")
	    delete (imlist, ver-)
	    delete (omsklist, ver-)
	    return
	}

# Begin main loop

	imglist = imlist
	omskimglist = omsklist
	outimglist = outimlist
	ssmskimglist = ssmsklist
	hmskimglist = hmsklist
	while (fscan (imglist, img) != EOF && fscan (outimglist,
	    subimg) != EOF && fscan (ssmskimglist, ssmsk) != EOF &&
	    fscan (hmskimglist, hmsk) != EOF) {

# Increment pointer.
	    ip += 1

# Get the output sky subtracted image name. If the image already exists
# delete it and any associated masks if the sky median of any image was
# recomputed.

	    fileroot (subimg, validim+)
	    subimg = fileroot.root
	    ext = fileroot.extension
	    if (ext != "")
		ext = "." // ext

	    fileroot (ssmsk, validim+)
	    ssmsk = fileroot.root // ".pl"

	    fileroot (hmsk, validim+)
	    hmsk = fileroot.root // ".pl"

	    if (skysub || ! imaccess (subimg // ext)) {
	        print ("Creating sky subtracted image ", subimg)
	        if (imaccess (subimg // ext)) {
		    imdelete (subimg // ext, ver-)
		}
	    } else {
		print ("Sky subtracted image ", subimg, " already exists")
		next
	    }

# Construct lists of input images and masks for this sky image. 

	    nml = tnmean / 2
	    nmh = tnmean - nml
	    if (ip - nml < 1) {
		start  = 1
		finish = max (ip + (ip - 1), nsmin + 1)
	    } else if (ip + nmh > nin) {
		start  = min (ip - (nin - ip), nin - nsmin)
		finish = nin
	    } else {
		start  = ip - nml
		finish = ip + nmh
	    }
	    if ((finish - start) <= 2 * nreject) {
		nrej = max ((finish - start) / 2 - 1, 0)
	    } else {
		nrej = nreject
	    }

	    nskyframes = finish - start
	    print ("    Frame  ",ip," Sky frames:  start = ",start,
		"  finish = ",finish,"  nreject = ",nrej)

	    templist = mktemp ("tmp$xslm")
	    xlist (imlist, templist, start, finish, ip, suffix="")

# Construct sky.   If we are using object masking, the parameter imcombine.
# plfile is used to create a .pl file called ssmsk  which, for each pixel in
# the sky frame, counts the number of images excluded from the final average by
# either pixel masking or rejection. This will later  be used to create the
# "holes" image. If there are any "holes" (i.e. regions where no images
# contributed to the final sky), the parameter imcombine.blank sets those
# pixels to 0. Note that these steps are not necessary if we are not masking,
# as nrej has been forced to be small enough so that at least one pixel will
# remain in the average.

	    if (imaccess ("_skytemp")) imdelete ("_skytemp", ver-)
	    if (imaccess (ssmsk)) {
	        imdelete (ssmsk, ver-)
	    }
	    if (msk)  {
		imcombine ("@"//templist, "_skytemp", headers="", bpmasks="",
		    rejmasks="", nrejmasks=ssmsk, expmasks="", sigmas="",
		    logfile="", comb="average", reject="minmax", project-,
		    outtype="real", outlimits="", offsets="none",
		    masktype="goodval", maskval=0., blank=0., scale="!SKYMED",
		    zero="none", weight="none", statsec="", expname="",
		    lthresh=INDEF, hthresh=INDEF, nlow=nrej, nhi=nrej, nkeep=0,
		    mclip+, lsigma=3.0, hsigma=3.0, rdnoise="0.0", gain="1.0",
		    snoise="0.0", sigscale=0.1, pclip=-0.5, grow=0)
	    } else {
		imcombine ("@"//templist, "_skytemp", headers="", bpmasks="",
		    rejmasks="", nrejmasks="", expmasks="", sigmas="",
		    logfile="", comb="average", reject="minmax", project-,
		    outtype="real", outlimits="", offsets="none",
		    masktype="none", blank=0., scale="!SKYMED", zero="none",
		    weight="none", statsec="", expname="", lthresh=INDEF,
		    hthresh=INDEF, nlow=nrej, nhi=nrej, nkeep=0, mclip+,
		    lsigma=3.0, hsigma=3.0, rdnoise="0.0", gain="1.0",
		    snoise="0.0", sigscale=0.1, pclip=-0.5, grow=0)
	    }

# Divide image by _skytemp frame to produce temporary ratio image _sclmsktemp.

	    if (imaccess ("_sclmsktemp")) {
	        imdelete ("_sclmsktemp", ver-)
	    }
	    imarith (img, "/", "_skytemp", "_sclmsktemp", divzero=0., title="",
	        hparams="", pixtype="real", calctype="real", ver-, noact-)

# Calculate median of unmasked (sky) pixels in _sclmsktemp and save in variable
# valmed. Delete _sclmsktemp image afterward.

	    if (msk) {
		maskfile = ""
		hselect (img, tomasks, yes) | scan (maskfile)
		if (maskfile != "") {
		    if (access (maskfile)) {
                        print ("    Using header object mask : ", maskfile)
		    } else {
			print ("    Cannot find object mask: ", maskfile)
    			maskfile = ""
		    }
		} else if (fscan (omskimglist, maskfile) != EOF) {
		    if (access (maskfile)) {
                        print ("    Using object mask : ", maskfile)
		    } else if (nin  > nomasks) {
			maskfile = ""
		    } else {
			print ("    Cannot find object mask: ", maskfile)
			maskfile = ""
		    }
		} else {
		    maskfile = ""
		}
		maskstat ("_sclmsktemp", maskfile, 0., lower=0., upper=INDEF,
		    iterstat+, statsec=statsec, nsigrej=nsigrej,
		    maxiter=maxiter, show-)
		valmed = maskstat.median
	    } else {
		maskfile = ""
		iterstat ("_sclmsktemp", statsec=statsec, nsigrej=nsigrej,
		    maxiter=maxiter, lower=INDEF, upper=INDEF, show-)
		valmed = iterstat.imedian
	    }
	    imdelete ("_sclmsktemp", ver-)

# Rescale _skytemp to object frame median and subtract from object. Replace
# with IMEXPR task.

	    imexpr ("a - b * c", subimg // ext, img, "" // valmed,
	        "_skytemp", dims="auto", intype="real", outtype="real",
		refim="auto", rangecheck=yes, bwidth=0, btype="nearest",
		bpixval=0.0, exprdb="none", verbose-)

# If we are using object masking, find "holes" in the sky subtracted frame
# wherever the sky frame had no unrejected pixels entering into the coaverage.   

	    if (msk) {
		if (imaccess (hmsk)) {
		    imdelete (hmsk, ve-) 
		}
                imstat (ssmsk, format-, fields="max", lower=INDEF, upper=INDEF,
		    binwidth=0.1, nclip=0, lsigma=3.0, usigma=3.0, cache-) |
		    scan (maxcsky)
		if (maxcsky == nskyframes && ! del_hmasks) {
		    #imstat (ssmsk, format-, fields="npix", lower=nskyframes,
		        #upper=nskyframes, binwidth=0.1) | scan (nholes)
		    #print ("There are ", nholes, " holes in output image ",
		        #subimg)
		    print ("    Creating holes mask: ", hmsk)
	    	    imexpr ("a >= b ? 0 : 1", hmsk, ssmsk, "" // nskyframes,
	        	dims="auto", intype="auto", outtype="auto",
			refim="auto", rangecheck=yes, bwidth=0,
			btype="nearest", bpixval=0.0, exprdb="none", verbose-)
		    hedit (subimg // ext, fields="HOLES", value=hmsk, add+,
		        delete-, verify-, update+, show-)
		}
		if (del_ssmasks) {
		    imdelete (ssmsk, ve-)
		}
	    }

# Add comment card to header of sky subtracted image.
 
	    if (msk) {
	        print ("Object masked and sky subtracted with nmean=", tnmean,
		    "nreject=", nreject) | scan (theadline)
	    } else {
	        print ("Sky subtracted with nmean=", tnmean, "nreject=",
		    nreject) | scan (theadline)
	    }
	    hedit (subimg // ext, "SKYSUB", theadline, add+, delete-, verify-,
	        update+, show-)

# Clean up.

	    imdelete ("_skytemp", ver-)
	    delete (templist, ver-)
	}

	if (msk) {
	    imglist = imlist
	    outimglist = outimlist
	    while (fscan (imglist, img) != EOF && fscan (outimglist,
	        subimg) != EOF) {
	        hedit (img, "BPM", maskfile, add-, delete+, verify-, show-,
		    update+)
	        hedit (subimg, "BPM", maskfile, add-, delete+, verify-, show-,
	            update+)
	    }
	}

	delete (imlist, ver-)
	delete (omsklist, ver-)
	delete (outimlist, ver-)
	delete (ssmsklist, ver-)
	delete (hmsklist, ver-)
	imglist = ""
	outimglist = ""
	omskimglist = ""
	ssmskimglist = ""
	hmskimglist = ""
end
