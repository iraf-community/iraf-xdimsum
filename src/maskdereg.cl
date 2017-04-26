# MASKDEREG creates individual object masks using the combined image object
# mask created by MKMASK and the sections file created by XNREGISTAR which
# defines the location of the each input image in the combined image.

procedure maskdereg (omask, sections, outlist)

# Maskdereg uses the imcopy, orient, fileroot, imdelete, xlist, fields, imsum,
# and delete tasks and the CL builtin imaccess and mktemp tasks.


string 	omask		{prompt="Input combined image object mask"}
string	sections	{prompt="The input sections file written by  xnregistar"}
string	outlist		{".obm", prompt="The list of output individual object masks or suffix"}
real 	y2n_angle   	{0.0, prompt="Angle in degrees from Y to N N thru E"}
bool 	rotation	{yes, prompt="Is N thru E CCW ?"}
bool	mkcrmask	{no, prompt="Cosmic ray  or sky subtraction mask?"}
bool	update		{yes, prompt="Add object mask name to image headers?"}

struct	*imglist
struct	*outimglist

begin
	int ix, iy, fx, fy, nim
	string tobjmask, tsections, toutlist, omsk, outimlist
	string img, fieldstring, msect, objlist

#	int imno, start, finish, ndiff
#	string cobjlist, tmpim

# Get query parameters

	tobjmask = omask
	tsections = sections
	toutlist = outlist

# Verify that the object mask exists.

	if (! imaccess (tobjmask)) {
	    print ("Error:  Object mask ", tobjmask," does not exist")
	    return
	}

# Verify that the sections file exists.

	if (! access (tsections)) {
	    print ("Error:  Sections file ", tsections," does not exist")
	    return
	}
	count (tsections) | scan (nim)

# Generate the output image list

	outimlist  = mktemp ("tmp$maskdereg")
        if (substr (toutlist, 1, 1) == ".") {
            imglist = tsections
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // toutlist
                print (img, >> outimlist)
            }
        } else {
            sections (toutlist, option="fullname", > outimlist)
            if (nim != sections.nimages) {
                print ("Error: Input and out object mask lists do not match")
                delete (outimlist, ver-)
                return
            }
        }


# Re-orient mask image which was erected by xnregistar to match input images.

	if (imaccess ("_maskimage.pl")) imdelete ("_maskimage.pl", ver-)
	imcopy (tobjmask, "_maskimage.pl", ver-)
	orient ("_maskimage.pl", y2n_angle, rotation=rotation, invert+)


# Make working mask images, one for each input image, by cutting out appropriate
# subsection of the input mosaic object mask image.  If update=yes insert mask
# name into input image headers with OBJMASK card.
# If mkcrmask=yes mask name is OBJmask* and field is CROBJMASK, 
# if mkcrmask=no mask name is objmask* and header field is OBJMASK

	if (mkcrmask) {
	    fieldstring="CROBJMASK"
	} else {
	    fieldstring="OBJMASK"
	}

# Loop over the input images.

	objlist = mktemp ("tmp$maskdereg")
	imglist = tsections
	outimglist = outimlist
	while (fscan (imglist, img, ix, iy, fx, fy) != EOF &&
	    fscan (outimglist, omsk) != EOF) {

	    print ("Making object masks for image: ", img)

	    fileroot (img, validim+)
	    img = fileroot.root
	    fileroot (omsk, validim+)
	    omsk = fileroot.root // ".pl"

	    msect = "["//ix//":"//fx//","//iy//":"//fy//"]"
	    if (imaccess (omsk)) {
	        imdelete (omsk, verify-)
	    }
	    imcopy ("_maskimage.pl" // msect, omsk, ver-)

	    print (omsk, >> objlist)
	    if (update) hedit (img, fieldstring, omsk, add+, ver-, up+, sho-)
	}

# Combine the object masks.

#	if (nprev_omask > 0) {
#	    count (objlist) | scan (nim)
#	    for (imno = nim; imno >= 1; imno = imno - 1) {
#		start = max (1, imno - nprev_omask)
#		finish = imno
#	    	cobjlist = mktemp ("tmp$maskdereg")
#		xlist (objlist, cobjlist, start, finish, 0, suffix="")
#		ndiff = finish - start
#		if (ndiff > 0) {
#		    fields (tsections, 1, lines="" // imno, quit_if_missing=no,
#			print_file_name=no) | scan (img)
#		    print ("Combining object mask for image: ", img,
#		        " with ", ndiff, " previous masks")
#		    if (imaccess ("_junk.pl")) imdelete ("_junk.pl", verify-)
#		    tmpim = "_junk.pl"
#                    imsum ("@" // cobjlist, tmpim, title="", hparams="",
#		        pixtype="", calctype="", option="sum", low_reject=0.0,
#			high_reject=0.0, verbose-) 
#		    fields (objlist, 1, lines=""//imno, quit_if_missing=no,
#			print_file_name=no) | scan (img)
#		    imdelete (img, verify-)
#		    imexpr ("a > 0 ? 1 : 0", img, tmpim, dims="auto",
#			intype="auto", outtype="auto", refim="auto",
#			bwidth=0, btype="nearest", bpixval=0.0, rangecheck=yes,
#			verbose-, exprdb="none")
#		    imdelete (tmpim, verify-)
#		}
#	    	delete (cobjlist, verify-)
#	    }
#	}

# Clean up.

	imdelete ("_maskimage.pl", ver-)
	delete (outimlist, verify-)
	delete (objlist, verify-)
	imglist = ""
	outimglist = ""
end
