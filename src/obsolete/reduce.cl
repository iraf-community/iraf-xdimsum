
# Combine the input images into a single mosaic after sky subtraction, bad pixel
# corrections, and cosmic ray cleaning. Object masks are not used in the first
# pass but are created from the combined image produced in the first pass step
# and used in the mask pass to create better sky images and do unzap cosmic
# rays that are part of object regions. The output is a list of sky subtracted,
# bad pixel cleaned, and cosmic ray cleaned images, a list of cosmic ray masks,
# a list of holes masks defining blank regions in the sky images, and the final
# combined image  and associated exposure map image. A file describing the
# position of the input images in the output image is also produced.
# The combined image object masks and the individual object masks are also
# saved.

procedure reduce (inlist, reference, sslist, crmasks, hmasks, output, expmap,
	sections)

# Xmosaic calls the xdimsum tasks mkmask, maskdereg, xslm, maskfix, xzap,
# xnzap, badpixupdate, xdshifts, xnregistar, and fileroot.
#
# Xmosaic also calls the IRAF tasks sections, imdelete and delete as well
# as the CL builtins mktemp and time.



string	inlist		{prompt="The list of input images"}
string  reference	{prompt="The reference image in input image list"}
string	sslist  	{".sub",prompt="The output sky-subtracted images or suffix"}
string	crmasks  	{".crm",prompt="The output cosmic ray masks or suffix"}
string	hmasks  	{".hom",prompt="The output holes masks or suffix"}
string	output		{prompt="Root name for output combined images"}

string	expmap		{".exp",prompt="Root name for output exposure map image or suffix"}
string	sections	{".corners",prompt="The for output sections list file or suffix"}

string	omask 	 	{".msk",prompt="The output first pass combined image mask or suffix"}
string	ocrmasks	{".ocm",prompt="The output cosmic ray unzapping masks or suffix"}
string	objmasks	{".obm",prompt="The output object masks or suffix"}

bool	fp_xslm		{yes,prompt="Do firstpass xslm ?"}
bool	fp_maskfix	{yes,prompt="Do firstpass maskfix ?"}
bool	fp_xzap		{yes,prompt="Do firstpass xzap ?"}
bool	fp_badpixupdate	{yes,prompt="Do firstpass bad pixel file update ?"}
bool	fp_mkshifts	{no,prompt="Determine shifts interactively ?"}
bool	fp_chkshifts 	{no,prompt="Check new shifts interactively ?"}
string	shiftlist	{"",prompt="Input shifts file if fp_mkshifts is off"}
real	fp_cradius	{5.0,prompt="Centroiding radius in pixels for mkshifts"}
real	fp_maxshift	{5.0,prompt="Maximum centroiding shift in pixels for mkshifts"}
bool	fp_xnregistar	{yes,prompt="Do firstpass xnregistar ?"}

bool	mp_mkmask	{yes,prompt="Make masks ?"}
bool	mp_chkmasks	{no,prompt="Check masks ?"}
bool	mp_kpchking 	{yes,prompt="Keep checking masks ?",mode="q"}
string  mp_statsec      {"",prompt="The combined image section for computing mask stats"}
real	mp_nsigcrmsk	{1.5,prompt="factor x suggested threshold for cr masking"}
real	mp_nsigobjmsk	{1.1,prompt="factor x suggested threshold for object masking"}
bool	mp_maskdereg 	{yes,prompt="Deregister masks ?"}
int	mp_nprev_omask	{0, prompt="Number of previous object masks to combine"}

bool    mp_xslm		{yes,prompt="Do maskpass xslm ?"}
bool	mp_useomask	{yes,prompt="Use object mask to compute sky statistics in maskpass ?"}
bool    mp_maskfix	{yes,prompt="Do maskpass fixpix ?"}
bool    mp_xzap		{yes,prompt="Do maskpass xzap ?"}
bool	mp_badpixupdate	{yes,prompt="Do maskpass bad pixel file update ?"}
bool	mp_xnregistar	{yes,prompt="Do maskpass xnregistar ?"}
int	mp_mag		{4,min=1,prompt="Mag factor for maskpass image"}

string  statsec         {"",prompt="The image section for computing sky stats"}
real    nsigrej         {3.0,prompt="The nsigma rejection for computing sky stats"}
int     maxiter         {20, prompt="The maximum number of iterations for sky stats"}

bool	forcescale 	{yes,prompt="Force recalculation of image medians in sky scaling ?"}
int	nmean		{6,min=1,prompt="Number of images to use in sky frame"}
int	nreject		{1,min=0,prompt="Number of pixels for xslm minmax reject"}
int     nskymin	 	{3,min=0,prompt="Minimum number of frames to use for sky"}

bool	forcefix 	{yes,prompt="Force bad pixel fixing ?"}
string	bpmask		{"",prompt="Bad pixel mask image"}

bool	newxzap		{yes,prompt="Use new version of xzap ?"}


bool	fractional	{no,prompt="Use fractional pixel shifts if mag = 1 ?"}
bool	pixin		{yes,prompt="Are input coords in ref object pixels ?"}
bool	ab_sense	{yes,prompt="Is A through B counterclockwise ?"}
real	xscale		{1.,prompt="X pixels per A coordinate unit"}
real	yscale		{1.,prompt="Y pixels per B coordinate unit"}
real	a2x_angle	{0.,prompt="Angle in degrees from A CCW to X"}

int	ncoavg		{1,min=1,prompt="Number of internal coaverages per frame"}
real	secpexp		{1.0,prompt="Seconds per unit exposure time"}

real	y2n_angle	{0.,prompt="Angle in degrees from Y to N N through E"}
bool	rotation	{yes,prompt="Is N through E counterclockwise?"}

bool    del_bigmasks    {no,prompt="Delete combined image masks at task termination ?"}
bool    del_smallmasks  {no,prompt="Delete the individual object masks at task termination ?"}

struct	*imglist
struct	*shlist

begin
	int	nin, nref, ifile
	string	itlist, stlist, ctlist, htlist, ssmtlist, ocrtlist, objtlist
	string	ushiftlist, toutput1, toutput2
	string	trefim, toutput, tsslist, tcrmasks, ext, texpmap1, texpmap2
	string	tsections, texpmap, thmasks, tomask, tocrmasks, tobjmasks
	string  msk, imsk, img, j1, j2, j3, j4

	print ("start")
	time ("")

	itlist = mktemp ("tmp$reduce")
	stlist = mktemp ("tmp$reduce")
	ctlist = mktemp ("tmp$reduce")
	htlist = mktemp ("tmp$reduce")
	ssmtlist = mktemp ("tmp$reduce")
	ocrtlist = mktemp ("tmp$reduce")
	objtlist = mktemp ("tmp$reduce")
	ushiftlist = mktemp ("tmp$reduce")

# Expand the list of input images and get query parameters.

	sections (inlist, option="fullname", > itlist)
	nin = sections.nimages
	trefim	 = reference
	tsslist = sslist
	tcrmasks = crmasks
	thmasks = hmasks

# Get the output image, output exposure map, and output sections file names.

	toutput = output
	fileroot (toutput, validim+)
	toutput = fileroot.root
	ext = fileroot.extension
	if (ext != "")
	    ext = "." // ext
	toutput1 = toutput // "_fp" // ext
	toutput2 = toutput // "_mp" // ext
	texpmap = expmap
	if (substr (texpmap, 1, 1) == ".") {
	    texpmap1 = toutput // "_fp" // texpmap // ext
	    texpmap2 = toutput // "_mp" // texpmap // ext
	} else {
	    fileroot (texpmap, validim+)
	    ext = fileroot.extension
	    if (ext != "")
	        ext = "." // ext
	    texpmap1 = fileroot.root // "_fp" // ext
	    texpmap2 = fileroot.root // "_mp" // ext
	}
	tsections = sections
	if (substr (tsections, 1, 1) == ".") {
	    tsections = toutput //  tsections
	}

	tomask = omask
	tocrmasks = ocrmasks
	tobjmasks = objmasks

# Create list of filenames for sky subtracted output files and determine the
# name of the reference image in the output sky subtracted image list.


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

# Create the holes mask list.

        if (substr (thmasks, 1, 1) == ".") {
            imglist = stlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // thmasks // ".pl"
                print (img, >> htlist)
                img = fileroot.root // ".ssm.pl"
                print (img, >> ssmtlist)
            }
        } else {
            sections (thmasks, option="fullname", > htlist)
            if (fileno != sections.nimages) {
                print ("Error: Input and holes image lists do not match")
                delete (itlist, ver-)
                delete (stlist, ver-)
                delete (ctlist, ver-)
                delete (htlist, ver-)
                delete (ssmtlist, ver-)
                return
            }
            imglist = stlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // ".ssm.pl"
                print (img, >> ssmtlist)
            }
        }


# Get the combined image mask name. The output mask directory will default to
# the  combined image directory. Get the individual object and cosmic ray
# unzapping masks. The output individual mask directory defaults to the sky
# subtracted image directory.

        if (substr (tomask, 1, 1) == ".") {
            #fileroot (outim, validim+)
            msk = toutput // tomask // ".pl"
            imsk = toutput // tomask // "i" // ".pl"
        } else {
            fileroot (tomask, validim+)
            msk = fileroot.root // ".pl"
            imsk = fileroot.root // "i" // ".pl"
        }

        if (substr (tocrmasks, 1, 1) == ".") {
            imglist = stlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tocrmasks // ".pl"
                print (img, >> ocrtlist)
            }
        } else {
            sections (tocrmasks, option="fullname", > ocrtlist)
            if (fileno != sections.nimages) {
                print ("Error: Input image and cosmic ray unzapping mask lists do not match")
                delete (itlist, ver-)
                delete (stlist, ver-)
                delete (ctlist, ver-)
                delete (ssmtlist, ver-)
                delete (htlist, ver-)
                delete (ocrtlist, ver-)
                return
            }
        }

        if (substr (tobjmasks, 1, 1) == ".") {
            imglist = stlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tobjmasks // ".pl"
                print (img, >> objtlist)
            }
        } else {
            sections (tobjmasks, option="fullname", > objtlist)
            if (fileno != sections.nimages) {
                print ("Error: Input image and object mask lists do not match")
                delete (itlist, ver-)
                delete (stlist, ver-)
                delete (ctlist, ver-)
                delete (ssmtlist, ver-)
                delete (htlist, ver-)
                delete (ocrtlist, ver-)
                delete (objtlist, ver-)
                return
            }
        }

# Call xslm, fixpix, and xzap to produce firstpass sky-subtracted frames

	if (fp_xslm) {
	    print ("begin first pass xslm")
	    time ("")
	    print ("-------Sky Subtracting------------------------------------")
	    xslm ("@" // itlist, "", nmean, "@" // stlist, ssmasks=".ssm",
		hmasks=".hom", statsec=statsec, nsigrej=nsigrej,
		maxiter=maxiter, nreject=nreject, nskymin=nskymin,
		forcescale=forcescale, useomask=no, del_ssmasks=yes,
		del_hmasks=no)
	    print ("")
	}

	if (fp_maskfix) {
	    print ("begin first pass maskfix")
	    time ("")
	    print ("-------Fixing bad pixels----------------------------------")
	    if (bpmask == "") {
	        print ("    The Bad pixel mask is undefined")
		delete (itlist, verify=no)
		delete (stlist, verify=no)
		delete (ctlist, verify=no)
		delete (htlist, verify=no)
		delete (ssmtlist, verify=no)
		return
	    }
	    maskfix ("@" // stlist, bpmask, 0, forcefix=forcefix)
	    print ("")
	}

	if (fp_xzap) {
	    print ("begin first pass xzap")
	    time ("")
	    if (newxzap) {
	        print("--------Zapping cosmic rays with xnzap----------------")
                xnzap ("@" // stlist, "", "@" // stlist, "@" // ctlist,
                    zboxsz=5, skyfiltsize=15, sigfiltsize=25, nsigzap=5.0,
		    nsigneg=0.0, nrejzap=1, nrings=0, nsigobj=5.0, ngrowobj=0,
		    del_crmask=no, verbose=no)
	    } else {
	        print("--------Zapping cosmic rays with xzap-----------------")
	        xzap ("@" // stlist, "", "@" // stlist, "@" // ctlist,
	            statsec=statsec, nsigrej=nsigrej, maxiter=maxiter,
		    checklimits+, zboxsz=5, zmin=-32768.0, zmax=32767.0,
		    nsigzap=5, nsigobj=2.0, subsample=2, skyfiltsize=15,
		    ngrowobj=0, nrings=0, nsigneg=0.0, del_crmask=no,
		    del_wmasks=yes, del_wimages=yes, verbose=no)
	    }
	    print ("")
	    if (fp_badpixupdate) {
		print ("badpix update")
		time ("")
	        print ("-------Updating bad pixel file with badpixupdate-----")
	        badpixupdate ("@" // ctlist, 3, bpmask)
	        print("")
	    }
	}

# Now make the shifts list
	
	if (fp_mkshifts) {
	    print("-------Making the shiftlist--------------------------------")
            print(" ")
	    if (access (shiftlist)) {
	        print ("    The shifts file ", shiftlist, " already exists")
	        delete (itlist, verify=no)
	        delete (stlist, verify=no)
	        delete (ctlist, verify=no)
	        delete (htlist, verify=no)
	        delete (ssmtlist, verify=no)
	        return
	    } else {
	        xdshifts ("@" // stlist, trefim, shiftlist, fp_cradius,
		    datamin=INDEF, datamax=INDEF, background=INDEF,
		    niterate=3, maxshift=fp_maxshift, chkshifts=fp_chkshifts)
		print ("")
		copy (shiftlist, ushiftlist, verbose-)
	    }
	} else if (! access (shiftlist)) {
	    print ("    The shifts file ", shiftlist, " is undefined")
	    delete (itlist, verify=no)
	    delete (stlist, verify=no)
	    delete (ctlist, verify=no)
	    delete (htlist, verify=no)
	    delete (ssmtlist, verify=no)
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

	if (fp_xnregistar) {
	    print ("begin first pass xregistar")
	    time ("")
	    print("-------Shifting and coadding images -----------------------")
            xnregistar (ushiftlist, bpmask, "", "", toutput1,
	        texpmap1, tsections, sinlist="@" // itlist, mag=1,
		fractional=fractional, pixin=pixin, ab_sense=ab_sense,
		xscale=xscale, yscale=yscale, a2x_angle=a2x_angle,
		ncoavg=ncoavg, secpexp=secpexp, y2n_angle=y2n_angle,
		rotation=rotation)
	    print ("")
	}


# On to the maskpass
	if (mp_mkmask) {
	    print ("begin mask pass mkmask")
	    time ("")
	    print("-------Making masks for unzapping object cores-------------")
	    if (imaccess (msk)) imdelete (msk, ver-)
	    mkmask (toutput1, texpmap1, msk, mp_nsigcrmsk,
	        statsec=mp_statsec, nsigrej=nsigrej, maxiter=maxiter, nsmooth=3,
		subsample=2, filtsize=15, ngrow=0, interact=mp_chkmasks)
	   if (mp_chkmasks) {
	       mp_kpchking = yes
	       while (mp_kpchking) {
	           if (imaccess (msk)) imdelete (msk, ver-)
		   mkmask (toutput1, texpmap1, msk, mp_nsigcrmsk,
		       statsec=mp_statsec, nsigrej=nsigrej, maxiter=maxiter,
		       nsmooth=3, subsample=2, filtsize=15, ngrow=0,
		       interact=mp_chkmasks)
	       }
           }
           print ("")

# Invert the mask for unzapping

           print ("-------Inverting mask for unzapping ----------------------")
           if (imaccess (imsk )) imdelete (imsk, ver-)
           minv (msk, imsk)
	   print ("")
	} else if (! access (msk)) {
	    print ("The mask required by maskdereg ", imsk, "does not exist")
	    delete (itlist, verify=no)
	    delete (stlist, verify=no)
	    delete (ctlist, verify=no)
	    delete (htlist, verify=no)
	    delete (ssmtlist, verify=no)
	    delete (ocrtlist, verify=no)
	    delete (objtlist, verify=no)
	    if (access (ushiftlist)) delete (ushiftlist, verify-)
	    return
	} else {
	    print ("-------Using existing object mask ", imsk, "---------------")
	}


# and deregister to make objmask for each frame. Note the cr+ in the maskdereg
# call.  This will unzap first pass crmasks even if mp_xzap is off.

	if (mp_maskdereg) {
	    print ("begin mask pass maskdereg")
	    time ("")
            print("------Deregistering unzap mask subsections ----------------")
	    imdelete ("@" // ocrtlist, ver-, >& "dev$null")
	    maskdereg (imsk, tsections, "@" // ocrtlist, y2n_angle=y2n_angle,
		rotation=rotation, update+, mkcrmask+, nprev_omask=0)
	    print ("")
	}	

	if (mp_mkmask) {
	    print ("begin mask pass mkmask")
	    time ("")
	     print("-------Making masks for sky subtraction-------------------")
	     if (imaccess (msk)) imdelete (msk, ver-)
	     mkmask (toutput1, texpmap1, msk, mp_nsigobjmsk,
	         statsec=mp_statsec, nsigrej=nsigrej, maxiter=maxiter,
		 nsmooth=3, subsample=2, filtsize=15, ngrow=0,
		 interact=mp_chkmasks)
	     if (mp_chkmasks) {
	         mp_kpchking = yes
	         while (mp_kpchking) {
	     	      if (imaccess (msk)) imdelete (msk, ver-)
		      mkmask (toutput1, texpmap1, msk,
		          mp_nsigobjmsk, statsec=mp_statsec, nsigrej=nsigrej,
			  maxiter=maxiter, nsmooth=3, subsample=2, filtsize=15,
			  ngrow=0, interact=mp_chkmasks)
	         }
             }
	     print ("")
	} else if (! access (msk)) {
	    print ("The mask required by maskdereg ", msk, "does not exist")
	    delete (itlist, verify=no)
	    delete (stlist, verify=no)
	    delete (ctlist, verify=no)
	    delete (htlist, verify=no)
	    delete (ssmtlist, verify=no)
	    delete (ocrtlist, verify=no)
	    delete (objtlist, verify=no)
	    if (access (ushiftlist)) delete (ushiftlist, verify-)
	    return
	} else {
	    print ("-------Using existing object mask ", msk, "---------------")
	}

	if (mp_maskdereg) {
	    print ("begin mask pass maskdereg")
	    time ("")
            print("-------Deregistering skysub mask subsections --------------")
	    imdelete ("@" // objtlist, ver-, >& "dev$null")
	    maskdereg (msk, tsections, "@" // objtlist, y2n_angle=y2n_angle,
		rotation=rotation, update+, mkcrmask-,
		nprev_omask=mp_nprev_omask)
	    print("")
	}

# Call xslm, fixpix, xzap, badpixupdate, and xregistar.

	if (mp_xslm) {
	    print ("begin mask pass xslm")
	    time ("")
            print("-------Sky subtracting images -----------------------------")
            imdelete ("@" // stlist, ver-, >& "dev$null")
	    imdelete ("@" // ssmtlist, ver-, >& "dev$null")
	    imdelete ("@" // htlist, ver-, >& "dev$null")
	    #xslm ("@" // itlist, "OBJMASK", nmean, "@" // stlist,
	    xslm ("@" // itlist, "@" // objtlist, nmean, "@" // stlist,
	        ssmasks="@" // ssmtlist, hmasks="@" // htlist, statsec=statsec,
		nsigrej=nsigrej, maxiter=maxiter, nreject=nreject,
		nskymin=nskymin, forcescale=forcescale, useomask=mp_useomask,
		del_ssmasks=yes, del_hmasks=no)
	  print("")
	}

	if (mp_maskfix) {
	    print ("begin mask pass maskfix")
	    time ("")
            print("-------Correcting bad pixels ------------------------------")
	    if (bpmask == "") {
	    	delete (itlist, verify=no)
	    	delete (stlist, verify=no)
	    	delete (ctlist, verify=no)
	    	delete (htlist, verify=no)
	    	delete (ssmtlist, verify=no)
	    	delete (ocrtlist, verify=no)
	    	delete (objtlist, verify=no)
		if (access (ushiftlist)) delete (ushiftlist, verify-)
		return
	    }
            maskfix ("@" // stlist, bpmask, 0, forcefix=forcefix)
            print("")
	}

# The mp xzap call has nobjsigma=0 and unzap=yes on the assumption that object
# masking is better done using the ocrmmask files from the combined image mask.

	if (mp_xzap) {
	    print ("begin mask pass xzap")
	    time ("")
	    if (newxzap) {
                print("-------Zapping cosmic rays with xnzap ----------------")
                #xnzap ("@" // stlist, "CROBJMAS", "@" // stlist, "@" // ctlist,
                xnzap ("@" // stlist, "@" // ocrtlist, "@" // stlist,
		    "@" // ctlist, zboxsz=5, skyfiltsize=15, sigfiltsize=25,
		    nsigzap=5.0, nsigneg=0.0, nrejzap=1, nrings=0, nsigobj=0.0,
		    ngrowobj=0, del_crmask=no, verbose=no)
	    } else {
                print("-------Zapping cosmic rays with xzap -----------------")
                #xzap ("@" // stlist, "CROBJMAS", "@" // stlist, "@" // ctlist,
                xzap ("@" // stlist, "@" // ocrtlist, "@" // stlist,
		    "@" // ctlist, statsec=statsec, nsigrej=nsigrej,
		    maxiter=maxiter, checklimits+, zboxsz=5, zmin=-32768.0,
		    zmax=32767.0, nsigzap=5, nsigobj=0.0, subsample=2,
		    skyfiltsize=15, ngrowobj=0, nrings=0, nsigneg=0.0,
		    del_crmask=no, del_wmasks=yes, del_wimages=yes, verb=no)
	    }
            print("")
	    if (mp_badpixupdate)  {
	        print("-------Updating bad pixel file -----------------------")
	        badpixupdate ("@" // ctlist, 3, bpmask)
	        print("")
	    }
	} else {
            print("-------Unaapping existing cosmic rays ----------------")
	    imarith ("@" // ocrtlist, "*", "@" // ctlist, "@" // ctlist,
	        title="", divzero=0.0, hparams="", pixtype="", calctype="",
	        ver-, noact-)
	}

	if (mp_xnregistar) {
	    print ("begin mask pass xregister")
	    time ("")
            print("------Magnifying and coadding images ---------------------")
	    #xnregistar (ushiftlist, bpmask, "CRMASK", "HOLES",
	    xnregistar (ushiftlist, bpmask, "@" // ctlist, "@" // htlist,
	        toutput2, texpmap2, "", sinlist="", mag=mp_mag,
		fractional=fractional, pixin=pixin, ab_sense=ab_sense,
		xscale=xscale, yscale=yscale, a2x_angle=a2x_angle,
		ncoavg=ncoavg, secpexp=secpexp, y2n_angle=y2n_angle,
		rotation=rotation)
	}

# Cleanup.
        if (del_bigmasks) {
            if (imaccess (msk)) imdelete (msk, verify-, >& "dev$null")
            if (imaccess (imsk)) imdelete (imsk, verify-, >& "dev$null")
        }
        if (del_smallmasks) {
            imdelete ("@" // ocrtlist, verify-, >& "dev$null")
            imdelete ("@" // objlist, verify-, >& "dev$null")
        }
	delete (itlist, verify=no)
	delete (stlist, verify=no)
	delete (ctlist, verify=no)
	delete (htlist, verify=no)
	delete (ssmtlist, verify=no)
	delete (ocrtlist, verify=no)
	delete (objtlist, verify=no)
	if (access (ushiftlist)) delete (ushiftlist, verify=no)

	imglist = ""
	shlist = ""

	print ("finish")
	time ("")
end
