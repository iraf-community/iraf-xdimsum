# Compute accurate shifts for a list of images taken in time sequence with
# a known approximate shift between adjacent images using star finding and
# list matching techniques.

# Note: Could rewrite the script to use fewer temporary files by looping
# over starfind and xyxymatch inside the same loop instead of looping over
# them in separate loops.

procedure xmshifts (inlist, output, shifts, hwhmpsf, threshold, xlag, ylag,
	tolerance)

string	inlist		{prompt="The input sky subtracted image sequence"}
string	output		{prompt="The output img, pixel shifts, and exposure time file"}
string	shifts		{"", prompt="The optional output relative shifts file"}
real	hwhmpsf		{1.25, prompt="The hwhm of the image psf in pixels"}
real	threshold	{50, prompt="The detection threshold in counts"}
real	xlag		{0.0, prompt="Initial shift in x in pixels"}
real	ylag		{0.0, prompt="Initial shift in y in pixels"}
real	tolerance	{5.0, prompt="List match tolerance in pixels"}
real	fradius		{2.5, prompt="Fitting radius in hwhmpsf"}
real	sepmin		{5.0, prompt="Minimum separation in hwhmpsf"}
real	datamin		{INDEF, prompt="Minimum good data value"}
real	datamax		{INDEF, prompt="Maximum good data value"}
real	roundlo		{0.0, prompt="Lower ellipticity limit"}
real	roundhi		{0.5, prompt="Upper ellipticity limit"}
real	sharplo		{0.5, prompt="Lower sharpness limit"}
real	sharphi		{2.0, prompt="Upper sharpness limit"}
int	nxblock		{INDEF, prompt="X dimension of working block size in pixels"}
int	nyblock		{INDEF, prompt="Y dimension of working block size in pixels"}


struct	*imglist

begin
	real	thwhmpsf, tthreshold, ttol, txlag, tylag
	real	xrm, yrm, xim,yim, dx, dy, sumdx, sumdy, tsep, sigma
	int	i, nimages, npts, idx, idy
	string	tinlist, toutput, tshifts
	string	coofiles, infiles, matfiles, img, refimg, cooimg
	string	shiftsdb

	# Get query parameters.
	tinlist = mktemp ("tmp$xmshifts")
	sections (inlist, option="fullname", > tinlist)
	count (tinlist) | scan (nimages)
	if (nimages <= 0) {
	    print ("The input image list is empty")
	    delete (tinlist, verify-)
	    return
	}
	toutput = output
	if (access (toutput)) {
	    print ("The output file: ", toutput, " already exists")
	    delete (tinlist, verify-)
	    return
	}
	tshifts = shifts
	if (tshifts != "") {
	    if (access (tshifts)) {
	        print ("The shifts file: ", tshifts, " already exists")
	        delete (tinlist, verify-)
	        return
	    }
	}
	thwhmpsf = hwhmpsf
	tthreshold = threshold
	txlag = xlag
	tylag = ylag
	ttol = tolerance

	print ("start")
	time ("")

	# Contruct temporary file names.
	infiles = mktemp ("tmp$xmshifts")
	coofiles = mktemp ("tmp$xmshifts")
	matfiles = mktemp ("tmp$xmshifts")
	shiftsdb = mktemp ("tmp$xmshifts")

	# Construct the output coordinate file list.
	imglist = tinlist
	i = 0
	while (fscan (imglist, img) != EOF) {
	    i += 1
	    fileroot (img, validim+)
	    img = fileroot.root
	    delete ("im" // i // ".coo.*", go_ahead+, verify-, >& "dev$null")
	    print ("im" // i // ".coo.1", >> coofiles)
	    delete ("im" // i // ".mat.*", go_ahead+, verify-, >& "dev$null")
	    print ("im"// i // ".mat.1", >> matfiles)

	}

	# Find stars in the images.
	print ("Begin star finding ...")
	time ("")
	imglist = tinlist
	i = 0
	while (fscan (imglist, img) != EOF) {
	    i += 1
	    fileroot (img, validim+)
	    img = fileroot.root
	    #print ("    Finding stars in ", img)
	    starfind (img, "im" // i // ".coo.1", thwhmpsf, tthreshold,
	        datamin=datamin, datamax=datamax, fradius=fradius,
		sepmin=sepmin, npixmin=5, maglo=INDEF, maghi=INDEF,
		roundlo=roundlo, roundhi=roundhi, sharplo=sharplo,
		sharphi=sharphi, wcs="logical", wxformat="", wyformat="",
		boundary="nearest", constant=0.0, nxblock=nxblock,
		nyblock=nyblock, verbose-)
	}


	# Contruct the reference coordinates list, the input coordinates list,
	# and the matched coordinates list. Delete any existing match files.
	imglist = tinlist
	for (i = 1; i <= nimages; i = i + 1) {
	    if (fscan (imglist, img) == EOF) {
		break
	    }
	    fileroot (img, validim+)
	    img = fileroot.root
	    delete ("im" // i // ".mat.*", go_ahead+, verify-, >& "dev$null")
	    if (i == 1) {
		print ("im" // i // ".coo.1", " ", "im" // i // ".coo.1", " ",
		    "im" // i // ".mat.1", >> infiles)
	    } else {
		print ("im" // i // ".coo.1", " ", "im" // i - 1 // ".coo.1",
		    " ", "im" // i // ".mat.1", >> infiles)
	    }
	    refimg = img
	}

	# Call xyxymatch.
	print ("Begin list matching ...")
	time ("")
	tsep = thwhmpsf * sepmin
	imglist = infiles
	while (fscan (imglist, img, refimg, cooimg) != EOF) {

	    #print ("    Matching lists ", img, " and ", refimg)
	    if (img == refimg) {
		xyxymatch (img, refimg, cooimg, tolerance=ttol, refpoints="",
		    xin=0.0, yin=0.0, xmag=1.0, ymag=1.0, xref=0.0,
		    yref=0.0, xrot=0.0, yrot=0.0, xcolumn=1, ycolumn=2,
		    xrcolumn=1, yrcolumn=2, separation=tsep,
	    	    matching="tolerance", nmatch=30, ratio=10.0, nreject=10,
	    	    xformat="%13.3f", yformat="%13.3f", interactive-, verbose-,
	    	    icommands="")
	    } else {
		xyxymatch (img, refimg, cooimg, tolerance=ttol, refpoints="",
		    xin=txlag, yin=tylag, xmag=1.0, ymag=1.0, xref=0.0,
		    yref=0.0, xrot=0.0, yrot=0.0, xcolumn=1, ycolumn=2,
		    xrcolumn=1, yrcolumn=2, separation=tsep,
	    	    matching="tolerance", nmatch=30, ratio=10.0, nreject=10,
	    	    xformat="%13.3f", yformat="%13.3f", interactive-, verbose-,
	    	    icommands="")
	    }
	}

	# Compute the shifts.
	print ("Begin computing individual shifts ...")
	time ("")
	imglist = tinlist
	for (i = 1; i <= nimages; i = i + 1) {
	    if (fscan (imglist, img) == EOF) {
		break
	    }
	    refimg = "im" // i // ".mat.1"
	    avshift (refimg) | scan (dx, dy, npts)
	    if (npts <= 0) {
		print ("    Warning shift for ", img, " is undefined")
		dx = -txlag
		dy = -tylag
	    }
	    #print ("    ", img, " ", dx, " ", dy)
	    print (img, " ", dx, " ", dy, >> shiftsdb)
	}

	# Create the output file to use as input by xnregister. Convert the
	# shifts to integer but output real values for the present.
	print ("Begin accumulating total shifts ...")
	time ("")
	sumdx = 0.0
	sumdy = 0.0
	imglist = shiftsdb 
	while (fscan (imglist, img, dx, dy) != EOF) {
	    sumdx = sumdx - dx
	    sumdy = sumdy - dy
	    if (sumdx == 0.0) {
		idx = 0
	    } else {
		idx = sumdx + (abs (sumdx) / sumdx) * 0.5
	    }
	    if (sumdy == 0.0) {
		idy = 0
	    } else {
		idy = sumdy + (abs (sumdy) / sumdy) * 0.5
	    }
	    printf ("%s  %0.3f %0.3f  1.0\n", img, sumdx, sumdy, >> toutput)
	}

	# Cleanup.
	if (tshifts != "") {
	    copy (shiftsdb, tshifts, verbose-)
	}
	delete (shiftsdb, verify-)
	delete ("@" // matfiles, verify-, go_ahead=yes, default_action=yes,
	    allversions=yes, subfiles=yes, >& "dev$null")
	delete (matfiles, verify-)
	delete (infiles, verify-)
	delete ("@" // coofiles, verify-, go_ahead=yes, default_action=yes,
	    allversions=yes, subfiles=yes, >& "dev$null")
	delete (coofiles, verify-)
	delete (tinlist, verify-)
	imglist = ""

	print ("finish")
	time ("")
end
