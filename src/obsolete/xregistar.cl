procedure xregistar (image_list, badpixfile, outimg)
	
# Replaced MKIMAGE with MKPATTERN -- 3/31/97 FV
#
# WARNING !! Recent adjustment made to the use of the 'exp' column in
# the shiftlist file -- magshiftfix no longer multiplies the image by
# that factor before adding it into the mosaic!  It DOES multiply the
# appropriate "_one" scaling image by that factor before adding it
# into the exposure map, however.  This is meant to be appropriate for
# using the 'exp' column to adjust for non-photometric scalings or
# differing relative exposure times.  It no longer serves as a weighting
# factor, however, unless exp=0, in which case magshiftfix just skips
# that image in the summation, as before.  This may not be a desirable 
# change and must be considered further.  In the meanwhile, be forewarned!
#   -- 10/17/93 MD
#
# Modified check for holes mask to use "HOLES" keyword in 
#  image header.  9/19/93 MD
# Check for zero weight in Shiftlist file, and if so, skip that
#  image rather than going through all the trouble just to end
#  up multiplying by zero...  9/19/93 MD
# Modified call to orientimg --> to call new routine orient. 7/22/93 MD
# Added parameter ncoavg to properly account for data take in
#  mode where multiple individual exposures are internally coaveraged
#  before readout. -- MD 7/15/93
# Debugging problem where pixin+ doesn't work 7 Dec
# Addtl. mod 16 Dec 1991 at KPNO 50" to reduce space needed, by
# deleting magnified images as soon as possible
# Modification of task newshiftfix to do  all integer shifts rather
# than imshift interpolation, by scaling input images up with
# block replication factor "mag" which is input.
# 5 Aug. 1991 Peter Eisenhardt
# Procedure to combine images taken at different locations
# into one big image, with no loss of spatial coverage or signal
# Assumes all input images have same dimensions
# Peter Eisenhardt 3 April 1989
# Modified 13 June 1989 to have scale and angle - unlike shiftpix,
# this version takes coordinate offsets as input.
# Further modified 21 Sept 1990 to allow masking of bad pixels specified
# in file bpixfile (uses fixpix format)
# Minor change 22 Oct/90 to add secpexp - seconds per exposure unit -
# Output is then in units of flux per second.
# Mofified 13 May 1991 to add parameter rotation which gives
# sense of North thru E.  Rotation is "true" if N thru E is CCW,
# which means "sign" is negative (and vice versa).  Rotation and
# angle are use in task orient, which does the transformation to
# put N near top and E near left.
# more mods 15 July 1991 -- changing way integers vs. fractions are handled
# so that always do "proper" integer shift
# also doing auto weighting assuming bundle format name
# and allowing different x and y scales
# Yet more mods 22 July 1991 to support sublocalmask --
# now generates addtl output file outimg//"._shift"
# Still even more additional mods 24 July -- separate dependence of
# NE, from input coords AB
# Don't need orientshiftlist call -- just want shifts in raw
# input coords, but do need to deshift mask pixel coords from final output coords
# Corrected error in newx , newy formulae for differing x and y scales,
# now in accordance with geomap

string	image_list 	{prompt="List of images, N and E shifts, and exposures"}
string	badpixfile	{prompt="The input bad pixel file"}
string	outimg		{prompt="The output combined image name"}
string	exp_prefix	{"exp_", prompt="The output exposure map prefix"}
string	crmasks		{"", prompt="Optional input CR mask list for mask pass"}
string	hmasks		{"", prompt="Optional input holes mask list for mask pass"}
string	in_prefix	{"", prompt="The optional first pass input image name prefix"}
string	oshift_suffix	{".shifts", prompt="The first pass output shifts file suffix"}

int	mag 		{4, min=1, prompt="Block replication factor"}
bool	pixin		{yes, prompt="Are input shifts in ref object pixels?"}
bool	ab_sense 	{yes, prompt="Is A thru B counterclockwise?"}
real	xscale 		{1.0,prompt="X pixels per A coordinate unit"}
real	yscale 		{1.0,prompt="Y pixels per B coordinate unit"}
real	a2x_angle 	{0.0, prompt="Angle in degrees from A CCW to X"}

int ncoavg      	{1, min=1, prompt="Number of internal coaverages per frame"}
real secpexp 		{60., prompt="Seconds per unit exposure time"}

real y2n_angle 		{0.0, prompt="Angle in degrees from Y to N N thru E"}
bool rotation 		{yes, prompt="Is N thru E CCW?"}


struct *imglist
struct *crimglist
struct *himglist

begin
	real axrad, a, b, newx, newy, xmin, xmax, ymin, ymax, xfrac, yfrac
	real navg, texp, mexp, seconds
	int sign, numsub, ixdim, iydim, ixmin, ixmax, iymin, iymax, oxdim, oydim
	int ix, iy, fx, fy, ilen
	string	rewind, oimg, bpfile, clist, hlist, oshifti, ext, img
	string crmaskfile, holesmask, which_one, strtemp

	string shimg			# shorter img name without 1st char
	string sect			# image section used for integer shift
	string headfile1, headfile2	# files for temporary storage of header
	struct theadline		# temporary struct for header data

# Initialize x and y min and max values so that they will be reset.

	xmin=9.0E+32
	ymin=9.0E+32
	xmax=-2.0E+9
	ymax=-2.0E+9	

# Get the query parameters

	rewind = image_list
	oimg = outimg
	bpfile = badpixfile

# Get cosmic ray image list
	clist = mktemp ("tmp$registar")
	sections (crmasks, option="fullname", > clist)

# Get holes image list
	hlist = mktemp ("tmp$registar")
	sections (hmasks, option="fullname", > hlist)

# Initialize geoemtry parameters.

	axrad = a2x_angle * 3.1415926535 / 180.0
	if (ab_sense) {
	    sign=1
	} else {
	    sign=-1
	}

# If input coords are measured in pixels with respect to reference object
# the scale is 1 but shifts are opposite sign of measured pixels. In this
# case a2x_angle is set to zero abd abs_ense is yes.

	if(pixin) {
	    xscale=-1.0
	    yscale=-1.0
	    axrad=0.0
	    sign=1
	}

# Determine the name of the output shifts file created by the first pass
# registration step.

	if (mag == 1) {
	    oshifti = oimg // oshift_suffix
	    numsub = strlen (in_prefix) + 1
	    if (access (oshifti)) delete (oshifti, ver-)
	}


# Check for existence of output files.

	fileroot ("")
	ext = fileroot.defextn
        if (access (oimg // ext)) {
            print ("Deleting existing output image", oimg // ext)
            imdelete (oimg, ve+)
        }

        if (access (exp_prefix // oimg // ext)) {
            print ("Deleting existing exposure image", exp_prefix // oimg // ext)
            imdelete (exp_prefix // oimg, ve+)
        }

# Delete existing temporary files.
 
        if (access ("_one" // ext)) imdelete ("_one" // ext, ver-)
        if (access("_this_one" // ext)) imdelete ("_this_one" // ext, ver-)

# Scan header of first image to get image dimensions.  We will assume for now
# that all images have the same size...

	imglist=rewind
	if (fscan (imglist, img, a, b) != EOF) {
	    imgets(img, "i_naxis1")
	    ixdim = int(imgets.value) 
	    imgets(img, "i_naxis2")
	    iydim = int(imgets.value) 
	}

# Find maximum and minimum x and y shift values and apply badpixel mask.

	imglist=rewind
	while (fscan (imglist, img, a, b) != EOF) {
	    newx = mag * (xscale * a * cos(axrad) +
	        yscale * b * sign * sin(axrad))
	    newy = mag * (yscale * b * sign * cos(axrad) -
	        xscale * a * sin(axrad))
	    if (newx < xmin)  {
		xmin = newx
	    }
	    if (newy < ymin)  {
		ymin = newy
	    }
	    if (newx > xmax) {
		xmax = newx
	    }
	    if (newy > ymax) {
		ymax = newy
	    }
	    if (mag == 1) {
		imarith (img, "*", bpfile, img, title="", divzero=0.0,
		    hparams="", pixtype="", calctype="", ver-, noact-)
	    }
	}

# Transform the shifts to integer values.
		
	ixmax=0
	ixmin=0
	iymax=0
	iymin=0
	if (xmax != 0.0) ixmax =int (xmax + 0.5 * (xmax / abs(xmax)))
	if (ymax != 0.0) iymax =int (ymax + 0.5 * (ymax / abs(ymax)))
	if (xmin != 0.0) ixmin =int (xmin + 0.5 * (xmin / abs(xmin)))
	if (ymin != 0.0) iymin =int (ymin + 0.5 * (ymin / abs(ymin)))

# Make a flat image for scaling position dependent exposure time. This has size
# of original input image so that bad pixel masking can be done.

	#mkimage("_one",ixdim,iydim,"r",1.,"Scaling image")
	mkpattern ("_one", pattern="constant", option="replace", v1=1.,
	    title="Scaling image", pixtype="r", ndim=2, ncols=ixdim,
	    nlines=iydim, header="")

# Set bad pixels to zero in the flat image 

	imarith ("_one", "*", bpfile, "_one", title="", divzero=0.0,
	    hparams="", calctype="", pixtype="", ver-)

# Now rescale up to mag size for output image

	ixdim = ixdim * mag
	iydim = iydim * mag
	oxdim = ixdim + ixmax - ixmin
	oydim = iydim + iymax - iymin

# Create magnified output images here.

	#mkimage(oimg,oxdim,oydim,"r",0.,"shifted")
	#mkimage("exp"//oimg,oxdim,oydim,"r",0.,"Exposure map")
	mkpattern (oimg, pattern="constant", option="replace", v1=0.,
	    title="shifted", pixtype="r", ndim=2, ncols=oxdim, nlines=oydim,
	    header="")
	mkpattern (exp_prefix // oimg, pattern="constant", option="replace",
	    v1=0., title="Exposure map", pixtype="r", ndim=2, ncols=oxdim,
	    nlines=oydim, header="")

# Now do the shifts.

	imglist=rewind
	crimglist = clist
	himglist = hlist
	while (fscan (imglist, img, a, b, texp) != EOF) {

	    print ("Shifting image ", img)

# Strip off extension if present.

	    fileroot (img, validim+)
	    img = fileroot.root

# Calculate integer shifts.

	    newx = mag * (xscale * a * cos(axrad) +
	        yscale * b *sign * sin(axrad))
	    newy = mag *(yscale * b * sign * cos(axrad) -
	        xscale * a * sin(axrad))
	    ix = 0
	    if (newx != 0.0) ix = int(newx + 0.5 * (newx / abs(newx)))
	    xfrac = newx - ix
	    ix = 1 + ix - ixmin
	    fx = ix + ixdim - 1
	    iy = 0
	    if (newy != 0.0) iy = int(newy + 0.5 * (newy / abs(newy)))
	    yfrac = newy - iy
	    iy = 1 + iy - iymin
	    fy = iy + iydim - 1

# Record shifts in oshifti if firstpass

	    if (mag==1) {
		shimg = substr(img, numsub, strlen(img))
		print (shimg, " ", ix, iy, >> oshifti)
	    }

# Check to see if weight is exactly zero, and if so skip this image.

	    if (texp == 0.0) {
		print ("    Image weight is zero in the sum.  Moving on...")
		next
	    }

# Construct the image section string
	    sect = "["//ix//":"//fx//","//iy//":"//fy//"]"

# If firstpass do fractional pixel shifts of both the img and the flat.
# Otherwise check for cosmic ray mask, and if it exists, combine it with the
# bad pixel file.
# First, we look for a file called "crm_"//img//".pl".  If that is not
# present, check the image header for the keyword CRMASK, and if present, look 
# for the file named there.  This allows the user some flexibility in not always
# having to rename the crmask file if different sky subtracted versions of
# the same image are used at various times.

	    if (imaccess ("_" // img)) imdelete ("_" // img, ver-)
	    if (mag == 1) {

	        imshift (img, "_" // img, xsh = xfrac, ysh=yfrac, shifts="",
		      int="linear",bo="constant",con=0.)
		imshift ("_one", "_this_one", xsh = xfrac, ysh=yfrac, shifts="",
		      int="linear", bo="constant",con=0.)
	        which_one = "_this_one" // ext

	    } else {

		crmaskfile = ""
		if (fscan (crimglist, crmaskfile) != EOF) {
		    if (access (crmaskfile)) {
		        print ("    Using prefixed cosmic ray mask file: ",
			    crmaskfile)
		    } else {
		        print ("    Cannot find cosmic ray mask file: ",
			    crmaskfile)
	                crmaskfile = ""
		    }
		} else {
		    hselect (img, "CRMASK", yes) | scan (crmaskfile)
		    if (crmaskfile != "") {
			if (access (crmaskfile)) {
			    print ("Using header cosmic ray mask file: ",
			        crmaskfile)
			} else {
		            print ("    Cannot find cosmic ray mask file: ",
			        crmaskfile)
			    crmaskfile = ""
			}
		    } else {
		        print ("    Cannot find cosmic ray mask file: ",
			    crmaskfile)
		    }
		}

		if (crmaskfile != "") {
		    imarith ("_one", "-", crmaskfile, "_this_one" // ext,
		        title="", divzero=0.0, hparams="", pixtype="",
			calctype="", ver-, noact-)
		    imreplace ("_this_one", 0., lower=INDEF, upper=0.,
		        radius=0.0)
		    which_one = "_this_one" // ext
		} else {
		    which_one = "_one" // ext
		}

# Check for "holes" mask, and if it exists, combine it into weighting mask.
		holesmask = ""
		if (fscan (himglist, holesmask) != EOF) {
		    if (access (holesmask)) {
		        print ("    Using prefixed holes mask file: ",
			    crmaskfile)
		    } else {
		        print ("    Cannot find holes mask file: ", holesmask)
	                holesmask = ""
		    }
		} else {
		    hselect (img, "HOLES", yes) | scan (holesmask)
		    if (holesmask != "") {
			if (access (holesmask)) {
			    print ("Using header holes mask file: ", holesmask)
			} else {
		            print ("    Cannot find holes mask file: ",
			        crmaskfile)
			    holesmask = ""
			}
		    } else {
		        print ("    Cannot find holes mask file: ", holesmask)
		    }
		}

		if (holesmask != "") {
		    imarith (which_one, "*", holesmask, "_this_one" // ext,
			title="", divzero=0.0, hparams="", pixtype="",
			calctype="", ver-, noact-)
		    which_one = "_this_one"//ext
		} 
			
# Set bad pixels, CR pixels, and holes to zero in copy of image named _img.

		imarith (img, "*", which_one, "_" // img, title="",
		    divzero=0.0, hparams="", pixtype="", calctype="",
		    ver-, noact-)

	    }


# The routine 'bundle.cl' averags all size bundles to a single unit of 
# exposure time regardless of how many units went into the bundle. To weight
# the cumulative exposure properly, we need to multiply each bundle by the
# number of units navg that went into it.  Currently this is read from the
# file name since the suffix 'bN' was attached for this purpose. Note that
# navg must be less than 10 i.e. a single digit for the following to work.
# Bundling is currently disabled.

	    #ilen = strlen (img)
	    #if(substr (img, ilen-1, ilen-1) == "b") {
		#strtemp=substr(img,ilen,ilen)
		#navg=real(strtemp)
	    #} else {
		navg = 1
	    #}
	    texp = texp * navg

# Multiply exposure by the number of internally coaveraged exposures per frame.

            texp = texp * ncoavg

# Now do the magnification and delete the temporary copy _img.

	    if (imaccess ("shift" // img)) imdelete ("shift" // img, ver-)
	    blkrep ("_" // img, "shift" // img, mag, mag)
	    imdelete ("_" // img, ver-)

# Divide by mag squared because want to conserve total number of counts 
# in input image.

	    mexp = (navg * ncoavg) / (mag * mag)
	    imarith ("shift" // img, "*", mexp, "shift" // img, title="",
	        divzero=0.0, hparams="", pixtype="real", calctype="real",
	        ver-, noact-)

# Make big empty image 
	    #mkimage("bigshift"//img,oxdim,oydim,"r",0.,"shifted")
	    mkpattern ("bigshift" // img, pattern="constant", option="replace",
	        v1=0., title="shifted", pixtype="r", ndim=2, ncols=oxdim,
		nlines=oydim, header="")

# and copy into the big image.

	    imcopy ("shift" // img, "bigshift" // img // sect, ver-)
	    imdelete ("shift" // img, verify=no)

# and finally sum into output image.

	    imarith("bigshift" // img, "+" ,oimg, oimg, title="", divzero=0.0,
	        hparams="", pixtype="real", calctype="real", ver-, noact-)
	    imdelete ("bigshift" // img, verify=no)

# Now make the image to scale for position dependent exposure time.

	    #mkimage("bigscale"//img,oxdim,oydim,"r",0.,"scaling")
	    mkpattern ("bigscale" // img, pattern="constant",
	        option="replace", v1=0., title="scaling", pixtype="r",
		ndim=2, ncols=oxdim, nlines=oydim, header="", header="")
	    seconds = secpexp * texp
	    print ("    Total effective exposure time for this frame is ",
	        seconds)
	    if (imaccess ("scale" // img)) imdelete ("scale" // img, ver-)
	    blkrep (which_one, "scale" // img, mag, mag)
	    imarith ("scale" // img, "*", seconds, "scale"//img, title="",
	        divzero=0.0, hparams="", pixtype="real", calctype="real",
		ver-, noact-)
	    imcopy ("scale" // img, "bigscale" // img //sect, ver-)
	    imdelete ("scale" // img, verify=no)
	    imarith ("bigscale" // img, "+", exp_prefix // oimg,
		exp_prefix // oimg, title="", divzero=0.0, hparams="",
		pixtype="real", calctype="real", ver-, noact-)
	    imdelete ("bigscale" // img, verify=no)
	    if (access ("_this_one" // ext)) {
		imdelete ("_this_one" // ext, ver-)
	    }
	}

	imdelete ("_one", verify=no)

# Divide output image sum by exposure map.

	imarith (oimg, "/", exp_prefix // oimg, oimg, title="", divzero=0.,
	    hparams="", pixtype="real", calctype="real", ver-, noact-)

# Orient these to N at top, E at left for iraf default

	orient(oimg, y2n_angle, rotation=rotation, invert-)
	orient (exp_prefix // oimg, y2n_angle, rotation=rotation, invert-)

# Copy header information from first input frame into the final mosaic and 
# exposure map images.  Set mosaic exposure time to 1 second, delete exposure
# time info from exposure map, and reset image titles.  Add comment card about
# origin of header information.

	print ("    Updating header information.")
	imglist=rewind			# rewind imglist
	if (fscan (imglist, img, a, b) != EOF) {
	    headfile1 = mktemp("registar")
	    headfile2 = mktemp("registar")
	    hfix (img, command="copy $fname " // headfile1)
	    match ("dimsum.slm", headfile1, stop+, print+, > headfile2)
	    hfix (oimg,
		command="delete $fname ve- ; copy " // headfile2 //" $fname")
	    hselect (img, "title", yes) | scan (theadline)
	    hedit (oimg, "exptime", "1", add+, ver-, show-, update+)
	    hedit (oimg, "title", "Register mosaic sum: " // theadline, ver-,
	        show-, update+)
	    hedit (exp_prefix // oimg, "title",
	        "Exposure time map: " // theadline, ver-, show-, update+)
	    hedit (oimg, "BPM,HOLES,SKYMED", delete+, ver-, show-, update+)
            time | scan (theadline) 
            addcomment (exp_prefix // oimg, "dimsum.registar:  " //theadline,
	        ver-)
            addcomment (oimg, "dimsum.registar:  " // theadline, ver-)
            addcomment (oimg,
	        "dimsum.registar:  Header data copied from file "//img, ver-)
	    delete (headfile1, ve-)
	    delete (headfile2, ve-)
	}

# Cleanup.
	delete (clist, ver-)
	delete (hlist, ver-)
	imglist = ""
	crimglist = ""
	himglist = ""

end
