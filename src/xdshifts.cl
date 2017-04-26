# Compute the relative shifts by marking common objects on the image display.

procedure xdshifts (inlist, refim, shiftlist, cradius)

string	inlist		{prompt="List of input sky subtracted images"}
string  refim		{prompt="Reference image  in image list"}
string	shiftlist	{prompt="The output shifts list"}
real	cradius		{5.0, prompt="The centering radius in pixels"}
real    datamin         {INDEF, prompt="Lower good data limit"}
real    datamax         {INDEF, prompt="Upper good data limit"}
real    background      {INDEF, prompt="Mean background level for centroiding"}
int     niterate        {3, prompt="The maximum number of centering iterations"}
real    maxshift        {5.0, prompt="The maximum X and Y shift in pixels"}
bool	chkshifts 	{no,prompt="Check new shifts interactively ?"}
int	nframes		{4, prompt="Number of frames for imexamine"}

struct	*imglist

begin

# Declare local variables.

	real	tcradius, xx, yy, x0, y0
	int	nimages, i, tboxsize, nshifts
	string	trefim, tshiftlist
	string	im_lst, exam_lst, align_lst, stars_lst, temp1, temp2

	im_lst = mktemp ("tmp$xdshifts")
	temp1 = mktemp ("tmp$xdshifts")
	temp2 = mktemp ("tmp$xdshifts")

# Create the input image list and get the reference image name shiflist name.

	sections (inlist, option="fullname", > im_lst)
	count (im_lst) | scan (nimages)
	trefim	 = refim
	if (trefim == "") {
	    imglist = im_lst
	    if (fscan (imglist, trefim) == EOF) {
		trefim = ""
	    }
	}
	if (! imaccess (trefim)) {
	    print ("Reference image ", trefim, " does not exist")
	    delete (im_lst, verify-)
	    return
	}
	tshiftlist = shiftlist
	if (access (tshiftlist)) {
	    print ("Output shifts file ", tshiftlist, " already exist")
	    delete (im_lst, verify-)
	    return
	}
	tcradius = cradius

# Create some temporary files.

	exam_lst  = tshiftlist // ".exam"
	align_lst = tshiftlist // ".align"
	stars_lst = tshiftlist // ".stars"
	
# Initialize display and imexamine tasks. Don't like having to do this but
# there is not an easy way around it except to save set and restore all the
# parameters.

	unlearn ("rimexam")
	rimexam.fittype="gaussian"
	rimexam.radius = tcradius
	rimexam.rplot = 2.0 * tcradius

	unlearn ("display")

# Now make the shifts list interactively.
	
	#print ("------Making the shiftlist--------------------------------")

# Examine the images a choose a registration star.

        print (" ")
        print ("Examine images ...")
	print ("    Select reference star which is present in all images")
	print ("    Type n key to display next image")
	print ("    Type p key to display previous image")
	print ("    Type q key to quit")
        print (" ")
	imexamine ("@" // im_lst, 1, "", logfile="", keeplog-, defkey="a",
	    autoredraw+, allframes+, nframes=nframes, ncstat=5, nlstat=5,
	    graphcur="", imagecur="", wcs="logical", xformat="", yformat="",
	    graphics="stdgraph", use_display+,
	    display="display(image='$1',frame=$2, fill=yes, >& 'dev$null')")

# Measure the position of the reference star in each image.

        print (" ")
        print ("Determine relative shifts using above reference star ...")
        print ("    Move cursor to the selected star") 
        print ("    Type a key to measure the selected star") 
	print ("    Type n key to move to the next image")
	print ("    Type q key to quit")
        print (" ")
	if (access (exam_lst)) delete (exam_lst, verify-)
	imexamine ("@" // im_lst, 1, "", logfile=exam_lst, keeplog+,
	    defkey="a", autoredraw+, allframes+, nframes=nframes, ncstat=5,
	    nlstat=5, graphcur="", imagecur="", wcs="logical", xformat="",
	    yformat="", graphics="stdgraph", use_display+,
	    display="display(image='$1',frame=$2,fill=yes, >& 'dev$null')")
	if (chkshifts) edit (exam_lst)

# Select a set of reference image registration stars but make sure the
# first star measured is the registration star.

        print (" ")
        print ("Select reference image registration stars ...")
        print ("    Move to reference star measured previously")
        print ("    Type a to measure reference star")
        print ("    Move to other promising looking stars")
        print ("    Type a to measure other registration stars")
	print ("    Type q key to quit")
        print (" ")
	if (access (stars_lst)) delete (stars_lst, verify-)
	imexamine (trefim, 1, "", logfile=stars_lst, keeplog+, defkey="a",
	    autoredraw+, allframes+, nframes=nframes, ncstat=5, nlstat=5,
	    graphcur="", imagecur="", wcs="logical", xformat="", yformat="",
	    graphics="stdgraph", use_display+,
	    display="display(image='$1',frame=$2,fill=yes, >& 'dev$null')")
	if (chkshifts) edit (stars_lst)

# Format the reference star list so that it is suitable for input to
# imcentroid. Save the coordinates of the registration star in the reference
# image in x0 and y0. 

	i = 0; xx = 0; yy = 0
	imglist = stars_lst
	while (fscan (imglist, xx, yy) != EOF) {
	   if (nscan() == 2) {
	       if (i == 0) {
		   x0 = xx
		   y0 = yy
		   i = i + 1
		}
		print (xx, yy, >> temp2)
	    }
	}
	imglist = ""

# Compute an initial shifts list suitable for input to the imcentroid task.
# The shifts file can only be created if the reference star coordinates
# were determined in the previous step.

	if (i != 0) {
	    imglist = exam_lst
	    while (fscan (imglist, xx, yy) != EOF) {
	        if (nscan() == 2) {
		    xx = x0 - xx
		    yy = y0 - yy
		    print (xx, yy, >> temp1)
	        }
	    }
	    imglist = ""
	}

# Compute the shifts using the imcentroid task.

	if (! access (temp1)) {
	    print ("The shifts file for centroiding is missing")
	} else if (! access (temp2)) {
	    print ("The reference coordinates file for centroiding is missing")
	} else {

	    tboxsize = 2 * int (tcradius) + 1
	    if (access (align_lst)) delete (align_lst, verify-)
	    imcentroid ("@" // im_lst, trefim, temp2, shifts=temp1,
	        boxsize=tboxsize, bigbox=13, negative=no,
	        background=background, lower=datamin, upper=datamax,
	        niterate=niterate, tolerance=0, maxshift=maxshift,
	        verbose-, >& align_lst)
	    delete (temp1, verify=no)
	    delete (temp2, verify=no)

# Reverse the sense of the shifts to those expected by the xdimsum xnregistar
# task.

	    imglist = align_lst
	    nshifts = 0
	    while (fscan (imglist, temp1) != EOF) {
		temp2 = substr (temp1, 1, 7)
		if (temp2 == "#Shifts") {
		    while (fscan (imglist, temp1, xx, temp2, yy) != EOF) {
			if (nshifts >= nimages)
			    break
			if (temp1 == "" || temp1 == "#Trim_Section")
			    break
	        	printf ("%s  %0.3f %0.3f 1.0\n", temp1, -xx, -yy,
			    >> tshiftlist)
			nshifts = nshifts + 1
		    }
		}
	    }
	    if (chkshifts) {
	        edit (tshiftlist)
		count (tshiftlist) | scan (nshifts)
	        if (nimages != nshifts)
		print ("Warning: The number of shifts != to number of images")
	    } else if (nimages != nshifts) {
		print ("Warning: The number of shifts != to number of images")
	    }

	}

	imglist = ""
	delete (exam_lst, verify=no)
	delete (align_lst, verify=no)
	delete (stars_lst, verify=no)
	delete (im_lst, verify=no)
end
