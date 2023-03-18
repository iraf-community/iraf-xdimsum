# Compute accurate shifts for a list of images taken in time sequence with
# a known approximate shift between adjacent images using star finding and
# list centroiding and matching techniques.

procedure xfshifts (inlist, output, shifts, hwhmpsf, threshold, xlag, ylag,
	cbox)

string	inlist		{prompt="The input sky subtracted image sequence"}
string	output		{prompt="The output img, pixel shifts, and exposure time file"}
string	shifts		{prompt="The optional output relative shifts file"}
real	hwhmpsf		{1.25, prompt="The hwhm of the image psf in pixels"}
real	threshold	{50, prompt="The detection threshold in counts"}
real	xlag		{0.0, prompt="Initial shift in x in pixels"}
real	ylag		{0.0, prompt="Initial shift in y in pixels"}
int	cbox		{7, prompt="The centering box size in pixels"}
real	fradius		{2.5, prompt="Fitting radius in hwhmpsf"}
real	sepmin		{5.0, prompt="Minimum separation in hwhmpsf"}
real	datamin		{INDEF, prompt="Lower good data limit"}
real	datamax		{INDEF, prompt="Upper good data limit"}
real	background	{INDEF, prompt="Mean background level for centroiding"}
real	roundlo		{0.0, prompt="Lower ellipticity limit"}
real	roundhi		{0.5, prompt="Upper ellipticity limit"}
real	sharplo		{0.5, prompt="Lower sharpness limit"}
real	sharphi		{2.0, prompt="Upper sharpness limit"}
int	niterate	{3, prompt="The maximum number of centering iterations"}
real	maxshift	{5.0, prompt="The maximum X and Y shift in pixels"}
int     nxblock         {INDEF, prompt="X dimension of working block size in pixels"}
int     nyblock         {INDEF, prompt="Y dimension of working block size in pixels"}


struct	*imglist
struct	*shlist

begin
	real	thwhmpsf, tthreshold, txlag, tylag
	real	dx, dy, sumdx, sumdy
	int	tcbox
	int	i, nimages, idx, idy
	string	tinlist, toutput, tshifts
	string	coofiles, inimages, inshifts, img, refimg, cooimg
	string	imcout, shiftsdb, keyword, line
	bool	findshift

	print ("start")
	time ("")

	# Get query parameters.
	tinlist = mktemp ("tmp$xfshifts")
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
	tcbox = cbox

	# Contruct temporary file names for xregister.
	inimages = mktemp ("tmp$xfshifts")
	coofiles = mktemp ("tmp$xfshifts")
	inshifts = mktemp ("tmp$xfshifts")
	imcout = mktemp ("tmp$xfshifts")
	shiftsdb = mktemp ("tmp$xfshifts")

	# Construct the output coordinate file list.
	imglist = tinlist
	i = 0
	while (fscan (imglist, img) != EOF) {
	    i += 1
	    fileroot (img, validim+)
	    img = fileroot.root
	    delete ("im" // i // ".coo.*", go_ahead+, verify-, >& "dev$null")
	    print ("im" // i // ".coo.1", >> coofiles)

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


	# Contruct the reference image, input image, and coordinate file list.
	imglist = tinlist
	for (i = 1; i <= nimages; i = i + 1) {
	    if (fscan (imglist, img) == EOF) {
		break
	    }
	    fileroot (img, validim+)
	    img = fileroot.root
	    if (i == 1) {
		print (img, " ", img, " ", "im1" // ".coo.1", >> inimages)
	    } else {
		print (refimg, " ", img, " ", "im" // i - 1 // ".coo.1",
		    >> inimages)
	    }
	    refimg = img
	}

	# Construct the input shifts file for imcentroid.
	print (-txlag, -tylag, >> inshifts)

	# Call imcentroid.
        print ("Begin list centroiding and computing relative shifts ...")
        time ("")
	imglist = inimages
	i = 1
	while (fscan (imglist, refimg, img, cooimg) != EOF) {

            #print ("    Aligning lists in images ", img, " and ", refimg)

	    if (refimg == img) {

		# Set the shift to zero.
		print (img, " ", 0.0, " ", 0.0, >& shiftsdb)

	    } else {

	        # Compute the shift.
	        imcentroid (img, refimg, cooimg, shifts=inshifts,
		    boxsize=tcbox, bigbox=tcbox, negative=no,
		    background=background, lower=datamin, upper=datamax,
		    niterate=niterate, tolerance=0, maxshift=maxshift,
		    verbose-, >& imcout)

	        # Record the shift.
	        findshift = no
	        shlist = imcout
	        while (fscan (shlist, line) != EOF) {
		    keyword = substr (line, 1, 7)
		    if (keyword == "#Shifts") {
		        if (fscan (shlist, img, dx, keyword, dy,
			    keyword) != EOF) {
			    print (img, " ", dx, " ", dy, >> shiftsdb)
		            findshift = yes
		        }
		    }
	        }
	        if (! findshift) {
		    print ("    Warning shift for image ", img, " is undefined")
		    print (img, " ", -txlag, " ", -tylag, >> shiftsdb)
	        }
	        delete (imcout, verify-, >& "dev$null")
	    }

	    i = i + 1
	}

	# Create the output file to use as input by sregister. Convert the
	# shifts to integer.
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
	    printf ("%s  %0.3f %0.3f 1.0\n", img, sumdx, sumdy, >> toutput)
	}

	# Cleanup.

	if (tshifts != "") {
	    copy (shiftsdb, tshifts, verbose-)
	}
	delete (shiftsdb, verify-)
	delete (inshifts, verify-)
	delete (inimages, verify-)
	delete ("@" // coofiles, verify-, go_ahead=yes, default_action=yes,
	    allversions=yes, subfiles=yes, >& "dev$null")
	delete (coofiles, verify-)
	delete (tinlist, verify-)

	shlist = ""
	imglist = ""

	print ("finish")
	time ("")

end
