# Combine the input images into a single mosaic after sky subtraction, bad pixel
# corrections, and cosmic ray cleaning. Object masks are created using the
# input combines image and exposure map from the firstpass and then deregistered
# into object masks for the individual images. Object masks are used in the
# xslm, xzap, and xnzap tasks to compute better sky images and to unzap cosmic
# rays that are part of object regions.  The output is a list of sky subtracted,
# bad pixel cleaned, and cosmic ray cleaned images, a list of cosmic ray masks,
# a list of holes masks defining blank regions in the sky images, and the final
# combined image  and associated exposure map image. A file describing the
# position of the input images in the output image is also produced.
# The combined image object masks and the individual object masks are also
# saved.

procedure xmaskpass (input, inexpmap, sections, output, outexpmap)

# Xmaskpass calls the xdimsum tasks mkmask, maskdereg, xslm, maskfix, xzap,
# xnzap, badpixupdate, xnregistar, and fileroot.
#
# Xmaskpass also calls the IRAF tasks sections, imdelete and delete as well
# as the CL builtins mktemp and time.

string	input		{prompt="The input first pass combined image"}
string	inexpmap	{prompt="The input first pass exposure map"}
string  sections	{"", prompt="The input first pass sections file"}
string	output		{prompt="The output combined image"}
string  outexpmap       {".exp",prompt="The output exposure map or suffix\n"}

string  statsec         {"",prompt="The image section for computing sky stats"}
real    nsigrej         {3.0,prompt="The nsigma rejection limit for computing sky stats"}
int     maxiter         {20, prompt="The maximum number of iterations for computing sky stats\n"}

bool	mkmask		{yes,prompt="Create the combined image object mask ?"}
string	omask		{".msk", prompt="The output combined image object mask"}
bool    chkmasks	{no,prompt="Check the object masks interactively ?"}
bool    kpchking     	{yes,prompt="Keep checking the object masks ?",mode="q"}
string  mstatsec        {"",prompt="The combined image section for computing sky stats"}
real	nsigcrmsk	{1.5, prompt="Nthreshold factor for cosmic ray masking"}
real	nsigobjmsk	{1.1, prompt="Nthreshold factor for object masking"}
bool	negthresh	{no, prompt="Use negative object masking thresholds ?"}
int	ngrow		{0, prompt="Object growing box half-width in pixels\n"}

bool	maskdereg	{yes,prompt="Deregister mask sections from main object mask ?"}
string  ocrmasks	{".ocm",prompt="The deregistered cosmic ray unzapping masks or suffix"}
string  objmasks	{".obm",prompt="The deregistered object masks or suffix\n"}

bool	xslm		{yes,prompt="Do the sky subtraction step ?"}
string  sslist		{".sub",prompt="The output sky subtracted images or suffix"}
bool    newxslm         {no,prompt="Use the new version of the xslm task ?"}
string  hmasks		{".hom",prompt="The output holes masks or suffix"}
bool	forcescale	{yes,prompt="Force recalculation of image medians in xslm ?"}
bool	useomask	{yes,prompt="Use object masks to compute sky stats in xslm?"}
int	nmean		{6,min=1,prompt="Number of images to use for sky image in xslm"}
int     nskymin		{3,prompt="Minimum number of images to use for sky image in xslm"}
int	nreject		{1,prompt="Number of pixels for xslm minmax reject"}
bool	cache		{yes,prompt="Enable cacheing in the new xslm task ?\n"}

bool	maskfix		{yes,prompt="Do the bad pixel correction step ?"}
string	bpmask		{"",prompt="The input bad pixel mask image"}
bool    forcefix        {yes,prompt="Force bad pixel fixing in maskfix ?\n"}

bool	xzap		{yes,prompt="Do cosmic ray correction step ?"}
string  crmasks		{".crm",prompt="The input / output cosmic ray masks or suffix"}
bool	newxzap		{no,prompt="Use new version of xzap ?"}
bool	badpixupdate	{yes,prompt="Do bad pixel file update ?"}
int	nrepeats	{3,prompt="Number of repeats for bad pixel status ?\n"}

bool	xnregistar	{yes,prompt="Do the image combining step ?"}
string  shiftlist       {"",prompt="The input shift list file"}
string  rmasks		{".rjm",prompt="The output rejection masks or suffix"}
int	nprev_omask	{0, prompt="Number of previous deregistered object masks to combine"}
bool	fractional	{no,prompt="Use fractional pixel shifts if mag = 1 ?"}
bool	pixin		{yes,prompt="Are input coords in ref object pixels ?"}
bool	ab_sense 	{yes,prompt="Is A through B counterclockwise?"}
real	xscale		{1.,prompt="X pixels per A coord unit"}
real	yscale		{1.,prompt="Y pixels per B coord unit"}
real	a2x_angle	{0.0,prompt="Angle in degrees from a CCW to x"}
real	mag		{4.0,min=1,prompt="Magnification factor for xnregistar"}
bool	blkrep    	{yes,prompt="Use block replication to magnify ?"}
int     ncoavg		{1,prompt="Number of internal coaverages per frame"}
real	secpexp		{1.0,prompt="Seconds per unit exposure time"}
real	y2n_angle	{0.,prompt="Angle in degrees from Y to N N thru E"}
bool	rotation	{yes,prompt="Is N through E counterclockwise ?\n"}

bool	del_bigmasks	{no,prompt="Delete combined image masks at task termination ?"}
bool	del_smallmasks	{no,prompt="Delete the individual object masks at task termination ?\n"}

struct  *imglist
struct  *shlist

begin
	int fileno
	string	sfim, expim, usections, tsslist, tcrmasks, thmasks, trmasks
	string	outim, outexpim, tomask, tocrmasks, tobjmasks
	string	tlist1, tlist2, ctlist2, ssmtlist2, htlist2, ocrtlist2
        string  objtlist2, ushiftlist, rtlist2, img, imgr, msk, imsk, omsk
	string	j1, j2, j3, j4

	print ("start xmaskpass")
	time  ("")

# Get query parameters.

	sfim = input
	if (! imaccess (sfim)) {
            print ("The combined input image ", sfim, " does not exist" )
	    return
	}
	expim = inexpmap
	if (! imaccess (expim)) {
            print ("The combined input exposure map ", expim, " does not exist" )
	    return
	}
        usections = sections
	if (! access (usections)) {
            print ("The input sections file ", usections, " does not exist" )
	    return
	}
	tsslist = sslist
	tcrmasks = crmasks
	thmasks = hmasks
	trmasks = rmasks
	outim = output
	outexpim = outexpmap
	if (substr (outexpim, 1, 1) == ".") {
	    fileroot (outim, validim+)
	    outexpim = fileroot.root // outexpim
	    if (fileroot.extension != "")
		outexpim = outexpim // "." // fileroot.extension
	}

	tomask = omask
	tocrmasks = ocrmasks
	tobjmasks = objmasks

# Create temporary lists of filenames for unskysubtracted and sky subtracted 
# output images, the cosmic ray masks, the holes masks, and the object and
# inverse object masks.
 
        tlist1 = mktemp ("tmp$xmaskass")
	tlist2 = mktemp ("tmp$xmaskpass")
	ctlist2 = mktemp ("tmp$xmaskpass")
	ssmtlist2 = mktemp ("tmp$xmaskpass")
	htlist2 = mktemp ("tmp$xmaskpass")
	rtlist2 = mktemp ("tmp$xmaskpass")
	ocrtlist2 = mktemp ("tmp$xmaskpass")
	objtlist2 = mktemp ("tmp$xmaskpass")
	ushiftlist = mktemp ("tmp$xmaskpass")

# Create the input image list.

	fileno = 0
        imglist = usections
        while (fscan (imglist, img) != EOF) {
	    fileno = fileno + 1
            print (img, >> tlist1)
	}

# Create the sky subtracted image list.

        if (substr (tsslist, 1, 1) == ".") {
            imglist = usections
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tsslist
                print (img, >> tlist2)
            }
        } else {
            sections (tsslist, option="fullname", > tlist2)
            if (fileno != sections.nimages) {
                print ("Error: Input and sky subtracted image lists do not match")
                delete (tlist1, ver-)
                delete (tlist2, ver-)
                return
            }
	}

# Create the cosmic ray mask list.

        if (substr (tcrmasks, 1, 1) == ".") {
	    if (xzap) {
                imglist = tlist2
                while (fscan (imglist, img) != EOF) {
                    fileroot (img, validim+)
                    img = fileroot.root // tcrmasks // ".pl"
                    print (img, >> ctlist2)
                }
	    } else {
                imglist = usections
                while (fscan (imglist, img) != EOF) {
                    fileroot (img, validim+)
        	    if (substr (tsslist, 1, 1) == ".") {
                        img = fileroot.root // tsslist // tcrmasks // ".pl"
		    } else {
                        img = fileroot.root // ".sub" // tcrmasks // ".pl"
		    }
                    print (img, >> ctlist2)
		}
	    }
        } else {
           sections (tcrmasks, option="fullname", > ctlist2)
            if (fileno != sections.nimages) {
                print ("Error: Input and cosmic ray image lists do not match")
                delete (tlist1, ver-)
                delete (tlist2, ver-)
                delete (ctlist2, ver-)
                return
            }
        }


# Create the holes mask list.

        if (substr (thmasks, 1, 1) == ".") {
            imglist = tlist2
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // thmasks // ".pl"
                print (img, >> htlist2)
                img = fileroot.root // ".ssm.pl"
                print (img, >> ssmtlist2)
            }
        } else {
            sections (thmasks, option="fullname", > htlist2)
            if (fileno != sections.nimages) {
                print ("Error: Input and holes image lists do not match")
                delete (tlist1, ver-)
                delete (tlist2, ver-)
                delete (ctlist2, ver-)
                delete (htlist2, ver-)
                return
            }
            imglist = tlist2
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // ".ssm.pl"
                print (img, >> ssmtlist2)
	    }
        }

# Create the rejection mask list

        if (substr (trmasks, 1, 1) == ".") {
            imglist = tlist2
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // trmasks // ".pl"
                print (img, >> rtlist2)
            }
        } else {
            sections (trmasks, option="fullname", > rtlist2)
            if (fileno != sections.nimages) {
                print ("Error: Input and rejection image lists do not match")
                delete (tlist1, ver-)
                delete (tlist2, ver-)
                delete (ctlist2, ver-)
                delete (htlist2, ver-)
                delete (ssmtlist2, ver-)
                delete (rtlist2, ver-)
                return
            }
        }

# Get the input image root name.

	fileroot (sfim, validim+)
	sfim = fileroot.root

# Get the combined image mask name. The output mask directory will default to
# the input combined image directory. Get the individual object and cosmic ray
# unzapping masks. The output individual mask directory defaults to the sky
# subtracted image directory.

	if (substr (tomask, 1, 1) == ".") {
	    #fileroot (outim, validim+)
	    msk = fileroot.root // tomask // ".pl" 
	    imsk = fileroot.root // tomask // "i" // ".pl" 
        } else {
	    fileroot (tomask, validim+)
	    msk = fileroot.root // ".pl"
	    imsk = fileroot.root // "i" // ".pl"
	}

        if (substr (tocrmasks, 1, 1) == ".") {
            imglist = tlist2
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tocrmasks // ".pl"
                print (img, >> ocrtlist2)
            }
        } else {
            sections (tocrmasks, option="fullname", > ocrtlist2)
            if (fileno != sections.nimages) {
                print ("Error: Input image and cosmic ray unzapping mask lists do not match")
                delete (tlist1, ver-)
                delete (tlist2, ver-)
                delete (ctlist2, ver-)
                delete (ssmtlist2, ver-)
                delete (htlist2, ver-)
                delete (rtlist2, ver-)
                delete (ocrtlist2, ver-)
                return
            }
        }

        if (substr (tobjmasks, 1, 1) == ".") {
            imglist = tlist2
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tobjmasks // ".pl"
                print (img, >> objtlist2)
            }
        } else {
            sections (tobjmasks, option="fullname", > objtlist2)
            if (fileno != sections.nimages) {
                print ("Error: Input image and object mask lists do not match")
                delete (tlist1, ver-)
                delete (tlist2, ver-)
                delete (ctlist2, ver-)
                delete (ssmtlist2, ver-)
                delete (htlist2, ver-)
                delete (rtlist2, ver-)
                delete (ocrtlist2, ver-)
                delete (objtlist2, ver-)
                return
            }
        }

# Create the initial object mask

	if (mkmask) {
	    print ("Begin mask pass inverse object mask creation")
	    time  ("")
	    print ("-------Making mask for unzapping object cores ------------")
	    if (imaccess (msk)) imdelete (msk, ver-)
	    mkmask (sfim, expim, msk, nsigcrmsk, negthresh=no, statsec=mstatsec,
		nsigrej=nsigrej, maxiter=maxiter, nsmooth=3, subsample=2,
		filtsize=15, ngrow=0, interact=chkmasks)
            if (chkmasks) {
                kpchking = yes
                while (kpchking) {
                    if (imaccess (msk)) imdelete (msk, ver-)
                    mkmask (sfim, expim, msk, nsigcrmsk, negthresh=no,
		        statsec=mstatsec, nsigrej=nsigrej, maxiter=maxiter,
			nsmooth=3, subsample=2, filtsize=15, ngrow=0,
			interact=chkmasks)
                }
            }
            print ("")
	    # Invert the mask for unzapping
	    print ("-------Inverting mask for unzapping ----------------------")
	    if (imaccess (imsk )) imdelete (imsk, ver-)
	    minv (msk, imsk)
	    print ("")

	} else if (! access (imsk)) {
	    print ("The mask required by maskdereg ", imsk, "does not exist")
	    delete (tlist1, ver-)
	    delete (tlist2, ver-)
	    delete (ctlist2, ver-)
	    delete (ssmtlist2, ver-)
	    delete (htlist2, ver-)
	    delete (rtlist2, ver-)
	    delete (ocrtlist2, ver-)
	    delete (objtlist2, ver-)
            if (access (ushiftlist)) delete (ushiftlist, ver-)
	    return
	} else {
	    print ("-------Using existing object mask ", imsk, "---------------")
	}
	print ("")

# and deregister to make object mask for each frame. Note the cr+ in the
# maskdegreg call. This will unzap the first pass crmasks even if xzap is
# off.

	if (maskdereg) {
	    print ("Begin mask pass individual inverse object mask creation")
	    time  ("")
            print("-------Deregistering unzap mask subsections ---------------")
	    imdelete ("@" // ocrtlist2, ver-, >& "dev$null")
	    maskdereg (imsk, usections, "@" // ocrtlist2, y2n_angle=y2n_angle,
	        rotation=rotation, update+, mkcrmask+)
	    print("")
	}

	if (mkmask) {
	    print ("Begin mask pass object mask creation")
	    time  ("")
	    print ("-------Making mask for sky subtraction -------------------")
	    if (imaccess (msk)) imdelete (msk, ver-)
	    mkmask (sfim, expim, msk, nsigobjmsk, negthresh=negthresh,
	        statsec=mstatsec, nsigrej=nsigrej, maxiter=maxiter, nsmooth=3,
		subsample=2, filtsize=15, ngrow=ngrow, interact=chkmasks)
	     print ("")
             if (chkmasks) {
                 kpchking = yes
                 while (kpchking) {
                      if (imaccess (msk)) imdelete (msk, ver-)
                      mkmask (sfim, expim, msk, nsigobjmsk,
		          negthresh=negthresh, statsec=mstatsec,
			  nsigrej=nsigrej, maxiter=maxiter, nsmooth=3,
			  subsample=2, filtsize=15, ngrow=ngrow, interact=chkmasks)
                 }
             }
	     print ("")
	} else if (! access (msk)) {
	    print ("The mask required by maskdereg ", msk, "does not exist")
	    delete (tlist1, ver-)
	    delete (tlist2, ver-)
	    delete (ctlist2, ver-)
	    delete (ssmtlist2, ver-)
	    delete (htlist2, ver-)
	    delete (rtlist2, ver-)
	    delete (ocrtlist2, ver-)
	    delete (objtlist2, ver-)
            if (access (ushiftlist)) delete (ushiftlist, ver-)
	    return
	} else {
	    print ("-------Using existing object mask ", msk, "---------------")
	}

	if (maskdereg) {
	    print ("Begin mask pass individual object mask creation")
	    time  ("")
            print("-------Deregistering sky subtraction mask subsections -----")
	    imdelete ("@" // objtlist2, ver-, >& "dev$null")
	    maskdereg (msk, usections, "@" // objtlist2, y2n_angle=y2n_angle,
	        rotation=rotation, update+, mkcrmask- )
	    print("")
	}

	if (xslm) {
	    print ("Begin mask pass sky subtraction")
	    time  ("")
            print("-------Sky subtracting images with xslm -------------------")
            imdelete ("@" // tlist2, ver-, >& "dev$null")
	    imdelete ("@" // ssmtlist2, ver-, >& "dev$null")
	    imdelete ("@" // htlist2, ver-, >& "dev$null")
	    #xslm ("@" // tlist1, "OBJMASK", nmean, "@" // tlist2,
	    if (newxslm) {
	        xnslm ("@" // tlist1, "@" // objtlist2, nmean, "@" // tlist2,
	            hmasks= "@" // htlist2, forcescale=forcescale,
		    useomask=useomask, statsec=statsec, nsigrej=nsigrej,
		    maxiter=maxiter, nreject=nreject, nskymin=nskymin,
		    cache=cache, del_hmasks=no)
	    } else {
	        xslm ("@" // tlist1, "@" // objtlist2, nmean, "@" // tlist2,
	            ssmasks ="@" // ssmtlist2, hmasks= "@" // htlist2,
		    forcescale=forcescale, useomask=useomask, statsec=statsec,
		    nsigrej=nsigrej, maxiter=maxiter, nreject=nreject,
		    nskymin=nskymin, del_ssmasks=yes, del_hmasks=no)
	    }
	    print("")
	}

	if (maskfix) {
	    print ("Begin mask pass bad pixel correction")
	    time  ("")
            print("-------Correcting bad pixels with maskfix------------------")
	    if (bpmask == "") {
		print ("    The bad pixel mask is undefined")
		delete (tlist1, ver-)
		delete (tlist2, ver-)
		delete (ctlist2, ver-)
		delete (ssmtlist2, ver-)
		delete (htlist2, ver-)
		delete (rtlist2, ver-)
		delete (ocrtlist2, ver-)
		delete (objtlist2, ver-)
		if (access (ushiftlist)) delete (ushiftlist, ver-)
		return
	    }
            maskfix ("@" // tlist2, bpmask, 0, forcefix=forcefix)
            print("")
	}

	if (xzap) {
	    print ("Begin mask pass cosmic ray correction")
	    time  ("")
	    if (newxzap) {
                print("-------Zapping cosmic rays using xnzap --------------------")
	        #xnzap ("@" // tlist2, "CROBJMAS", "@" // tlist2, "@" // ctlist2,
	        xnzap ("@" // tlist2, "@" // ocrtlist2, "@" // tlist2,
		    "@" // ctlist2, zboxsz=5, skyfiltsize=15, sigfiltsize=25,
		    nsigzap=5.0, nsigneg=0.0, nrejzap=1, nrings=0, nsigobj=0.0,
		    ngrowobj=0, del_crmask=no, verbose=no)
	    } else {
                print("-------Zapping cosmic rays using xzap ---------------------")
                #xzap ("@" // tlist2, "CROBJMAS", "@" // tlist2, "@" // ctlist2,
                xzap ("@" // tlist2, "@" // ocrtlist2, "@" // tlist2,
		    "@" // ctlist2, statsec=statsec, nsigrej=nsigrej,
		    maxiter=maxiter, checklimits+, zboxsz=5, zmin=-32768.0,
		    zmax=32767.0, nsigzap=5, nsigobj=0.0, subsample=2,
		    skyfiltsize=15, ngrowobj=0, nrings=0, nsigneg=0.0,
		    del_crmask=no, del_wmasks=yes, del_wimages=yes, verb=no)
	    }
            print("")
	    if (badpixupdate)  {
	        print ("begin badpixupdate")
	        time  ("")
	        if (bpmask == "") {
		    print ("    The bad pixel mask is undefined")
		    delete (tlist1, ver-)
		    delete (tlist2, ver-)
		    delete (ctlist2, ver-)
		    delete (ssmtlist2, ver-)
		    delete (htlist2, ver-)
		    delete (rtlist2, ver-)
		    delete (ocrtlist2, ver-)
		    delete (objtlist2, ver-)
		    if (access (ushiftlist)) delete (ushiftlist, ver-)
		    return
	        }
                print("-------Updating bad pixel file with badpixupdate ----------")
                badpixupdate ("@" // ctlist2, nrepeats, bpmask)
                print("")
	    }
	} else {
	    print ("-------Unzapping existing CR masks -----------------------")
	    imarith ("@" // ocrtlist2, "*", "@" // ctlist2, "@" // ctlist2 ,
	        title="", divzero=0.0, hparams="", pixtype="", calctype="",
		ver-, noact-)
	    print("")
	}

	if (xnregistar) {
	    print ("Begin mask pass image combining")
	    time  ("")
	    if (shiftlist == "") {
		print("-------The shifts file is undefined ----------------")
	    } else if (! access (shiftlist)) {
		print("-------The shifts file does not exist --------------")
	    } else {
                print("-------Magnifying and coadding images with xnregistar -----")
                imglist = tlist2
                shlist = shiftlist
                while (fscan (imglist, img) != EOF && fscan (shlist, j1, j2,
		    j3, j4) != EOF) {
                    print (img, " ", j2, " ", j3, " ", j4, >> ushiftlist)
                }
                imdelete ("@" // rtlist2, ver-, >& "dev$null")
		xmskcombine ("@" // tlist2, bpmask, "@" // ctlist2,
		    "@" // htlist2, "@" // objtlist2, "@" // rtlist2, 
		    nprev_omask=nprev_omask)
	        xnregistar (ushiftlist, "@" // rtlist2, outim, outexpim, "",
		    sinlist="", blkrep=blkrep, mag=mag, fractional=fractional,
		    pixin=pixin, ab_sense=ab_sense, xscale=xscale,
		    yscale=yscale, a2x_angle=a2x_angle, ncoavg=ncoavg,
		    secpexp=secpexp, y2n_angle=y2n_angle, rotation=rotation)
	    }
	}

# Clean up.

	if (del_bigmasks) {
	    if (imaccess (msk)) imdelete (msk, verify-, >& "dev$null")
	    if (imaccess (imsk)) imdelete (imsk, verify-, >& "dev$null")
	}
	if (del_smallmasks) {
	    imdelete ("@" // ocrtlist2, verify-, >& "dev$null")
	    imdelete ("@" // objtlist2, verify-, >& "dev$null")
	}
	delete (tlist1, ver-)
	delete (tlist2, ver-)
	delete (ctlist2, ver-)
	delete (ssmtlist2, ver-)
	delete (htlist2, ver-)
	delete (rtlist2, ver-)
	delete (ocrtlist2, ver-)
	delete (objtlist2, ver-)
	if (access (ushiftlist)) delete (ushiftlist, ver-)
	imglist = ""
	shlist = ""

	print ("finish xmaskpass")
	time  ("")

end
