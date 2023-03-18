
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

procedure xmosaic (inlist, reference, output, expmap)

# Xmosaic calls the xdimsum tasks xfirstpass, xmaskpass and fileroot.


string	inlist		{prompt="The list of input images"}
string  reference	{prompt="The reference image in input image list"}
string	output		{prompt="Root name for output combined images"}
string	expmap		{".exp",prompt="Root name for output exposure map image or suffix\n"}

bool	fp_xslm		{yes,prompt="Do the first pass sky subtraction step ?"}
bool	fp_maskfix	{yes,prompt="Do first pass bad pixel correction step ?"}
bool	fp_xzap		{yes,prompt="Do first pass cosmic ray correction step ?"}
bool	fp_badpixupdate	{yes,prompt="Do first pass bad pixel mask update ?"}
bool	fp_mkshifts	{no,prompt="Determine first pass shifts interactively ?"}
bool	fp_xnregistar	{yes,prompt="Do first pass image combining step ?\n"}

bool	mp_mkmask	{yes,prompt="Create the combined image object mask ?"}
bool	mp_maskdereg 	{yes,prompt="Deregister masks ?"}
bool    mp_xslm		{yes,prompt="Do the mask pass sky subtraction step ?"}
bool    mp_maskfix	{yes,prompt="Do mask pass bad pixel correction step ?"}
bool    mp_xzap		{yes,prompt="Do mask pass cosmic ray correction step ?"}
bool	mp_badpixupdate	{yes,prompt="Do mask pass bad pixel mask update ?"}
bool	mp_xnregistar	{yes,prompt="Do mask pass image combining step ?\n"}

string  statsec         {"",prompt="The image section for computing sky stats"}
real    nsigrej         {3.0,prompt="The nsigma rejection for computing sky stats"}
int     maxiter         {20, prompt="The maximum number of iterations fo computing sky stats\n"}

string	sslist  	{".sub",prompt="The output sky-subtracted images or suffix"}
string	hmasks  	{".hom",prompt="The output holes masks or suffix"}
bool	newxslm 	{no,prompt="Use new version of xslm ?"}
bool	forcescale 	{yes,prompt="Force recalculation of image medians ?"}
int	nmean		{6,min=1,prompt="Number of images to use in sky image"}
int	nreject		{1,min=0,prompt="Number of pixels for sky image minmax reject"}
int     nskymin	 	{3,min=0,prompt="Minimum number of image to use for sky image"}
bool	cache	 	{yes,prompt="Enable cacheing in new version of xslm ?"}
bool	mp_useomask	{yes,prompt="Use object mask to compute sky statistics ?\n"}

string	bpmask		{"",prompt="The input pixel mask image"}
bool	forcefix 	{yes,prompt="Force bad pixel fixing ?\n"}

string	crmasks  	{".crm",prompt="The output cosmic ray masks or suffix"}
bool	newxzap		{no,prompt="Use new version of xzap ?"}
int	nrepeats	{3,prompt="Number of repeats for bad pixel status\n"}

bool	fp_chkshifts 	{yes,prompt="Check and confirm new shifts  ?"}
real	fp_cradius	{5.0,prompt="Centroiding radius in pixels for mkshifts"}
real	fp_maxshift	{5.0,prompt="Maximum centroiding shift in pixels for mkshifts\n"}

string	rmasks  	{".rjm",prompt="The output rejection masks or suffix"}
int	mp_nprev_omask	{0, prompt="Number of previous object masks to combine"}
bool	mp_blkrep	{yes,prompt="Use block replication to magnify the image ?"}
real	mp_mag		{4,min=1,prompt="Magnification factor for mask pass output image"}
string	shiftlist	{"",prompt="Input or output shifts file"}
string	sections	{".corners",prompt="The output sections file or suffix"}
bool	fractional	{no,prompt="Use fractional pixel shifts if mag = 1 ?"}
bool	pixin		{yes,prompt="Are input coords in ref object pixels ?"}
bool	ab_sense	{yes,prompt="Is A through B counterclockwise ?"}
real	xscale		{1.,prompt="X pixels per A coordinate unit"}
real	yscale		{1.,prompt="Y pixels per B coordinate unit"}
real	a2x_angle	{0.,prompt="Angle in degrees from A CCW to X"}
int	ncoavg		{1,min=1,prompt="Number of internal coaverages per frame"}
real	secpexp		{1.0,prompt="Seconds per unit exposure time"}
real	y2n_angle	{0.,prompt="Angle in degrees from Y to N N through E"}
bool	rotation	{yes,prompt="Is N through E counterclockwise?\n"}

string	omask 	 	{".msk",prompt="The output combined image mask or suffix"}
bool	mp_chkmasks	{no,prompt="Check the object masks ?"}
bool	mp_kpchking 	{yes,prompt="Keep checking the object masks ?"}
string  mp_statsec      {"",prompt="The combined image section for computing mask stats"}
real	mp_nsigcrmsk	{1.5,prompt="The nthreshold factor for cosmic ray masking"}
real	mp_nsigobjmsk	{1.1,prompt="The ntrheshold factor for object masking"}
bool	mp_negthresh	{no,prompt="Set negative object masking threshold ?"}
int	mp_ngrow	{0,prompt="Object region growing radius in pixels\n"}

string	ocrmasks	{".ocm",prompt="The output cosmic ray unzapping masks or suffix"}
string	objmasks	{".obm",prompt="The output object masks or suffix"}

bool    del_bigmasks    {no,prompt="Delete combined image masks at task termination ?"}
bool    del_smallmasks  {no,prompt="Delete the individual object masks at task termination ?\n"}

begin
	string	tinlist, treference, tsslist, tcrmasks, thmasks, toutput
	string	texpmap, tsections, toutput1, toutput2, texpmap1, texpmap2
	string	ext

	print ("start xmosaic")
	time ("")
	print ("")

# Get query parameters.

	tinlist = inlist
	treference = reference
	tsslist = sslist
	tcrmasks = crmasks
	thmasks = hmasks

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
	    tsections = toutput // "_fp" // tsections
	}

# Call xfirstpass.

	if (fp_xslm || fp_maskfix || fp_xzap || fp_badpixupdate || 
	    fp_mkshifts || fp_xnregistar) { 
	    xfirstpass (tinlist, treference, toutput1, texpmap1,
	        statsec=statsec, nsigrej=nsigrej, maxiter=maxiter,
		xslm=fp_xslm, sslist=tsslist, newxslm=newxslm,
		forcescale=forcescale, nmean=nmean, nskymin=nskymin,
		nreject=nreject, cache=cache, maskfix=fp_maskfix,
		bpmask=bpmask, forcefix=forcefix, xzap=fp_xzap,
		crmasks=tcrmasks, newxzap=newxzap, badpixupdate=fp_badpixupdate,
		nrepeats=nrepeats, mkshifts=fp_mkshifts, chkshifts=fp_chkshifts,
		cradius=fp_cradius, maxshift=fp_maxshift,
		xnregistar=fp_xnregistar, shiftlist=shiftlist,
		sections=tsections, fractional=fractional, pixin=pixin,
		ab_sense=ab_sense, xscale=xscale, yscale=yscale,
	        a2x_angle=a2x_angle, ncoavg=ncoavg, secpexp=secpexp,
	        y2n_angle=y2n_angle, rotation=rotation)
	}

	print ("")

# Call xmaskpass.

	if (mp_mkmask || mp_maskdereg || mp_xslm || mp_maskfix || mp_xzap ||
	    mp_badpixupdate || mp_xnregistar) { 
	    xmaskpass.kpchking = mp_kpchking
	    xmaskpass (toutput1, texpmap1, tsections, toutput2, texpmap2,
	        statsec=statsec, nsigrej=nsigrej,
	        maxiter=maxiter, mkmask=mp_mkmask, omask=omask,
	        chkmasks=mp_chkmasks, mstatsec=mp_statsec,
		nsigcrmsk=mp_nsigcrmsk, nsigobjmsk=mp_nsigobjmsk,
		negthresh=mp_negthresh, ngrow=mp_ngrow, maskdereg=mp_maskdereg,
		ocrmasks=ocrmasks, objmasks=objmasks,
		nprev_omask=mp_nprev_omask, xslm=mp_xslm, sslist=tsslist,
	        hmasks=thmasks, newxslm=newxslm, forcescale=forcescale,
		useomask=mp_useomask, nmean=nmean, nskymin=nskymin,
		nreject=nreject, cache=cache, maskfix=mp_maskfix, bpmask=bpmask,
		forcefix=forcefix, xzap=mp_xzap, crmasks=tcrmasks,
		newxzap=newxzap, badpixupdate=mp_badpixupdate,
		nrepeats=nrepeats, xnregistar=mp_xnregistar,
		shiftlist=shiftlist, rmasks=rmasks, fractional=fractional,
		pixin=pixin, ab_sense=ab_sense, xscale=xscale, yscale=yscale,
		a2x_angle=a2x_angle, mag=mp_mag, blkrep=mp_blkrep,
		ncoavg=ncoavg, secpexp=secpexp, y2n_angle=y2n_angle,
		rotation=rotation, del_bigmasks=del_bigmasks,
		del_smallmasks=del_smallmasks)
	}

	print ("")
	print ("finish xmosaic")
	time ("")
end
