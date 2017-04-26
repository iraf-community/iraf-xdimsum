# Combine the input images into a single mosaic after sky subtraction, bad pixel
# corrections, and cosmic ray cleaning. Object masks are not used in the first
# pass. The output is a list of sky subtracted, bad pixel cleaned, and cosmic
# ray cleaned images, a list of cosmic ray masks, and the combined image
# and associated exposure map image. A file describing the position of the
# input images in the output image is also produced.

procedure xfirstpass (inlist, reference, output, expmap)

# Xfirstpass calls the xdimsum tasks xslm, maskfix, xzap, xnzap, badpixupdate,
# xdshifts, xnregistar, and fileroot.
#
# Xfirstpass also calls the IRAF tasks sections and delete as well as the
# CL builtins mktemp and time.

string	inlist		{"", prompt="The list of input images"}
string	reference 	{"", prompt="The reference image in input image list"}
string	output		{"", prompt="The output combined image"}
string	expmap		{".exp",prompt="The output exposure map or suffix\n"}

string	statsec		{"",prompt="The image section for computing image stats"}
real	nsigrej		{3.0,prompt="The nsigma rejection for computing image stats"}
int	maxiter		{20, prompt="The maximum number of iterations for image stats\n"}

bool	xslm		{yes,prompt="Do the sky subtraction step?"}
string	sslist		{".sub",prompt="The output sky subtracted image list or suffix"}
bool	newxslm		{no,prompt="Use new version of xslm ?"}
bool	forcescale	{yes,prompt="Force recalculation of image medians in xslm ?"}
int	nmean		{6,min=1,prompt="Number of images to use for sky image in xslm"}
int     nskymin 	{3,min=0,prompt="Minimum number of frames to use for sky image in xslm"}
int	nreject		{1,min=0,prompt="Number of pixels for xslm minmax reject"}
bool	cache		{yes,prompt="Enable cacheing in new version of xslm ?\n"}

bool	maskfix		{yes,prompt="Do the bad pixel correction step ?"}
string	bpmask		{"",prompt="The input bad pixel mask"}
bool	forcefix	{yes,prompt="Force bad pixel fixing in maskfix ?\n"}

bool	xzap		{yes,prompt="Do the cosmic ray correction step ?"}
string	crmasks		{".crm",prompt="The output cosmic ray mask list or suffix"}
bool	newxzap		{no,prompt="Use new version of xzap ?"}
bool	badpixupdate	{yes,prompt="Update bad pixel mask ?"}
int	nrepeats	{3,prompt="Number of repeats for bad status ?\n"}

bool	mkshifts	{no,prompt="Determine the shiftlist interactively ?"}
bool	chkshifts	{yes,prompt="Check the new shifts ?"}
real	cradius		{5.0, prompt="Centroiding radius in pixels for mkshifts"}
real	maxshift	{5.0, prompt="Maximum centroiding shift in pixels for mkshifts\n"}

bool	xnregistar	{yes,prompt="Do the image combining step ?"}
string  shiftlist	{"",prompt="The input / output shift file"}
string	sections 	{".corners", prompt="The output sections list file or suffix"}	
bool	fractional	{no, prompt="Do fractional shifts in xnregistar step ?"}

bool	pixin		{yes,prompt="Are input coords in reference object pixels ?"}
bool	ab_sense	{yes,prompt="Is A through B axis rotation counterclockwise ?"}
real	xscale		{1.,prompt="X pixels per A coordinate unit"}
real	yscale		{1.,prompt="Y pixels per B coordinate unit"}
real	a2x_angle	{0.0,prompt="Angle in degrees from A CCW to X"}
int	ncoavg		{1,min=1,prompt="Number of internal coaverages per frame"}
real	secpexp		{1.0,prompt="Seconds per unit exposure time"}
real	y2n_angle	{0.,prompt="Angle in degrees from Y to N N through E"}
bool	rotation	{yes,prompt="Is N through E CCW ?\n"}


struct	*imglist
struct	*shlist

begin
	int	ifile, nin, nref
	string	itlist, stlist, trefim, ctlist, toutput, img, j1, j2, j3, j4
	string	texpmap, tsections, tsslist, tcrmasks, ushiftlist

	print ("start xfirstpass")
	time("")
	print("")

# Create temporary files.

	itlist = mktemp ("tmp$xfirstpass")
	stlist = mktemp ("tmp$xfirstpass")
	ctlist = mktemp ("tmp$xfirstpass")
	ushiftlist = mktemp ("tmp$xfirstpass")

# Get query parameters.

	sections (inlist, option="fullname", > itlist)
	nin = sections.nimages
	trefim = reference
	tsslist = sslist
	tcrmasks = crmasks
	toutput = output
	texpmap = expmap
	if (substr (texpmap, 1, 1) == ".") {
	    fileroot (toutput, validim+)
	    texpmap = fileroot.root // texpmap
	    if (fileroot.extension != "")
		texpmap = texpmap // "." // fileroot.extension 
	}
	tsections = sections
	if (substr (tsections, 1, 1) == ".") {
	    fileroot (toutput, validim+)
	    tsections = fileroot.root // tsections
	}
	
# Create temporary list of filenames for sky subtracted output files and
# determine the name of the reference image in the output sky subtracted
# image list.

        if (substr (tsslist, 1, 1) == ".") {
	    if (trefim != "") {
	        fileroot (trefim, validim+)
	        trefim = fileroot.root // tsslist 
	    }
            imglist = itlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tsslist
                print (img, >> stlist)
            }
        } else {
            sections (tsslist, option="fullname", > stlist)
            if (nin != sections.nimages) {
                print ("Error: Input and sky subtracted image lists do not match")
                delete (itlist, ver-)
                delete (stlist, ver-)
                return
            }
	    if (trefim != "") {
	        fileroot (trefim, validim+)
	        trefim = fileroot.root 
		ifile = 0
	        imglist = itlist
                while (fscan (imglist, img) != EOF) {
		    ifile += 1
                    fileroot (img, validim+)
                    img = fileroot.root 
		    if (img == trefim) break
	        }
		nref = ifile
	        if (nref == 0) {
		    trefim = ""
	        } else {
		    ifile = 0
	            imglist = stlist
                    while (fscan (imglist, img) != EOF) {
		        ifile += 1
		        if (ifile != nref) next
		        fileroot (img, validim+)
		        trefim = fileroot.root
		        break
		    }
	        }
	    }
        }

# Create temporary list of filenames for the cosmic ray masks.

        if (substr (tcrmasks, 1, 1) == ".") {
            imglist = stlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tcrmasks // ".pl"
                print (img, >> ctlist)
            }
        } else {
            sections (tcrmasks, option="fullname", > ctlist)
            if (nin != sections.nimages) {
                print ("Error: Input and cosmic ray image lists do not match")
                delete (itlist, ver-)
                delete (stlist, ver-)
                delete (ctlist, ver-)
                return
            }
        }

# Call xslm, maskfix, xzap, badpixupdate, and xnregistar.

	if (xslm) {
	    print ("Begin first pass sky subtraction")
	    time("")
	    print("-------Sky subtracting images with xslm--------------")
	    if (newxslm) {
	        xnslm ("@" // itlist, "", nmean, "@" // stlist, hmasks=".hom",
		    forcescale=forcescale, useomask=no, statsec=statsec,
		    nsigrej=nsigrej, maxiter=maxiter, nreject=nreject,
		    nskymin=nskymin, cache=cache, del_hmasks=no)
	    } else {
	        xslm ("@" // itlist, "", nmean, "@" // stlist, ssmasks=".ssm",
	            hmasks=".hom", forcescale=forcescale, useomask=no,
		    statsec=statsec, nsigrej=nsigrej, maxiter=maxiter,
		    nreject=nreject, nskymin=nskymin, del_ssmasks=yes,
		    del_hmasks=no)
	    }
	    print("")
	}

	if (maskfix) {
	    print ("Begin first pass bad pixel correction")
	    time("")
	    print("-------Correcting bad pixels with maskfix------------")
	    if (bpmask == "") {
		print ("Error: The bad pixel image is undefined")
		delete (itlist, ver-)
		delete (stlist, ver-)
		delete (ctlist, ver-)
		return
	    }
	    maskfix ("@" // stlist, bpmask, 0, forcefix=forcefix)
	    print("")
	}

	if (xzap) {
	    print ("Begin first pass cosmic ray removal")
	    time("")
	    if (newxzap) {
	        print("-------Zapping cosmic rays using xnzap   -------------")
	        xnzap ("@" // stlist, "", "@" // stlist, "@" // ctlist,
	            zboxsz=5, skyfiltsize=15, sigfiltsize=25, nsigzap=5.0,
		    nsigneg=0.0, nrejzap=1, nrings=0, nsigobj=5.0, ngrowobj=0,
		    del_crmask=no, verbose=no)
	    } else {
	        print("-------Zapping cosmic rays using xzap   -------------")
	        xzap ("@" // stlist, "", "@" // stlist, "@" // ctlist,
		    statsec=statsec, nsigrej=nsigrej, maxiter=maxiter,
		    checklimits+, zboxsz=5, zmin=-32768.0, zmax=32767.0,
		    nsigzap=5.0, nsigobj=2.0, subsample=2, skyfiltsize=15,
		    ngrowobj=0, nrings=0, nsigneg=0.0, del_crmask=no,
		    del_wmasks=yes, del_wimages=yes, verbose=no)
	    }
	    print("")
	    if (badpixupdate) {
	        print ("Begin first pass bad pixel mask update")
	        time("")
	        if (bpmask == "") {
		    print ("Error: The bad pixel image is undefined")
		    delete (itlist, ver-)
		    delete (stlist, ver-)
		    delete (ctlist, ver-)
		    return
	        }
	        print("-------Updating bad pixel file with badpixupdate ----")
	        badpixupdate ("@" // ctlist, nrepeats, bpmask)
	        print("")
	    }
	}

	if (mkshifts) {
	    print ("------- Making the shiftlist---------------------------")
	    if (access (shiftlist)) {
	        print ("    The shifts list ", shiftlist, " already exists")
	        delete (itlist, ver-)
	        delete (stlist, ver-)
	        delete (ctlist, ver-)
	        return
	    } else {
		xdshifts ("@" // stlist, trefim, shiftlist, cradius,
		    datamin=INDEF, datamax=INDEF, background=INDEF, niterate=3,
		    maxshift=maxshift, chkshifts=chkshifts)
	        print("")
		copy (shiftlist, ushiftlist, verbose-)
	    }
	} else if (! access (shiftlist)) {
	    print ("    The shifts list ", shiftlist, " is undefined")
	    delete (itlist, ver-)
	    delete (stlist, ver-)
	    delete (ctlist, ver-)
	    return
	} else {
	    print ("------- Checking the shiftlist---------------------------")
	    imglist = stlist
	    shlist = shiftlist
	    while (fscan (imglist, img) != EOF && fscan (shlist, j1, j2, j3,
	        j4) != EOF) {
		print (img, " ", j2, " ", j3, " ", j4, >> ushiftlist) 
	    }
	}

	if (xnregistar) {
	    print ("Begin first pass image combining")
	    time("")
	    if (shiftlist == "") {
	        print("-------The shifts file is undefined ----------------")
	    } else if (! access (shiftlist)) {
	        print("-------The shifts file does not exist --------------")
	    } else {
	        print("------- Creating rejection masks using xmskcombine  --")
		xmskcombine ("@" // stlist, bpmask, "", "",  "", ".rjm",
		    nprev_omask=0)
	        print("-------Coadding images using xnregistar --------------")
	        xnregistar (ushiftlist, "REJMASK",  toutput, texpmap,
		    tsections, sinlist="@" // itlist, blkrep=yes, mag=1.0,
		    fractional=fractional, pixin=pixin, ab_sense=ab_sense,
		    xscale=xscale, yscale=yscale, a2x_angle=a2x_angle,
		    ncoavg=ncoavg, secpexp=secpexp, y2n_angle=y2n_angle,
		    rotation=rotation)
	    }
	    print("")
	}

	delete (itlist, ver-)
	delete (stlist, ver-)
	delete (ctlist, ver-)
	if (access (ushiftlist)) delete (ushiftlist, ver-)
	imglist = ""
	shlist = ""

	print ("finish xfirstpass")
	time("")
end
