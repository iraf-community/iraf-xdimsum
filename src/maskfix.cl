# MASKFIX replaces the bad pixels in the input image using a bad pixel mask,
# a bad pixel mask value, and linear interpolation.

procedure maskfix (inlist, bpmasks, badvalue)

# Maskfix uses the sections, fileroot, delete, imcopy, hselect, chpixtype
# imgets, hedit, and maskinterp tasks as well as the CL builtins access,
# mktemp, and imaccess.

string inlist		{prompt="The input image list"}
string bpmasks		{prompt="The bad pixel mask list"}
int badvalue		{prompt="The bad pixel value in the mask"}
bool forcefix		{no, prompt="Force the bad pixel fixing ?"}

string *imglist
string *bplist

begin

int	badv, ipixtype, nimgs, nbp, junk
string	inlst,img, bad, badimh, badl, infile, bpfile
bool	firstim, badtoimh, copied

# Get query parameters

	inlst = inlist
	badl = bpmasks
	badv = badvalue

# Expand input lists

	infile = mktemp ("tmp$maskfix")
	sections (inlst, option="fullname", > infile)
	nimgs = sections.nimages

	bpfile = mktemp ("tmp$maskfix")
	sections (badl, option="fullname", > bpfile)
	nbp = sections.nimages

# Check validity of image lists

	if (nbp == 0) {
	    print ("Error: The bad pixel list is undefined")
	    delete (infile, ver-)
	    delete (bpfile, ver-)
	    return
	} else if (nbp == 1) {
	    ;
	} else if (nbp != nimgs) {
	    print ("Error: Image and bad pixel lists don't match")
	    delete (infile, ver-)
	    delete (bpfile, ver-)
	    return
	}

	badtoimh = no
	copied = no

# Main interpolation loop

	imglist = infile
	bplist = bpfile
	firstim = yes
	while (fscan (imglist, img) != EOF) {

# Get name of bad pixel file if nbp > 1

	    if (nbp == 1) {
		if (firstim) junk = fscan (bplist, bad)
	    } else {
		junk = fscan( bplist, bad)
	    }
	    fileroot (bad, validim+)
	    bad = fileroot.root // ".pl"
	    firstim = no

# If specified bad pixel file is a .pl mask, make default extension version;
# otherwise, check for existence of default extension version. Not sure why
# this is necesary at present.

	    if (nbp != 1 || ! badtoimh) {
 
		fileroot (bad, validim+)
		badimh = fileroot.root // fileroot.defextn
		if (fileroot.extension == "pl") {
                    if (! access (badimh)) {
			badimh = "_badtemp" // fileroot.defextn
                        imcopy (bad, badimh, verbose-)
			copied = yes
		    }
		}

# Check for existence of default extension version of bad pixel mask.
 
        	if (! access (badimh)) {
                    print ("Bad pixel file ", badimh, " does not exist")
		    delete (bpfile, ver-)
		    delete (infile, ver-)
                    return
        	}
 
# Make sure that default extension version of bad pixel file is of data type
# short.
                 
        	hselect (badimh, "i_pixtype", "yes") | scan (ipixtype)
        	if (ipixtype != 3) {
                    chpixtype (badimh, badimh, "short", verbose-)
        	}

		badtoimh = yes
	    }

# Do the interpolation.

	    imgets (img, "MASKFIX", >& "dev$null")
	    if (forcefix) {
	        print ("Fixing bad pixels in file ", img, " using mask ", bad)
	        maskinterp (img, badimh, badv)
		hedit (img, "MASKFIX", bad, add+, del-, ver-, show-, update+)
	    } else if (imgets.value == "0") {
	        print ("Fixing bad pixels in file ", img, " using mask ", bad)
	        maskinterp (img, badimh, badv)
		hedit (img, "MASKFIX", bad, add+, del-, ver-, show-, update+)
	    } else if (imgets.value != bad) {
	        print ("Fixing bad pixels in file ", img, " using mask ", bad)
	        maskinterp (img, badimh, badv)
		hedit (img, "MASKFIX", bad, add+, ver-, del-, show-, update+)
	    } else {
		print ("Bad pixels in ", img, " already fixed using mask ",
		    bad)
	    }


# Delete temporary default extension copy of bad pixel mask if nbp > 1.

	    if (nbp != 1 && copied) imdelete (badimh, ver-)

	}

# Delete temporary default extension copy of bad pixel mask if nbp = 1.

	if (nbp == 1 && copied) imdelete (badimh,ver-)
	delete (bpfile, ver-)
	delete (infile, ver-)

	imglist = ""
	bplist = ""

end	
