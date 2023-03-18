# Add the previous  object masks together. The input list is either the
# list of input object masks (keyword = "") or the list of parent images
# containing the object mask keyword. The current mimage is defined by
# the integer current and the nprev masks to that are summed to produce
# the output mask.

procedure xaddmasks (inmasks, current, nprev, keyword, outmask)

string	inmasks			{prompt="List of input images or object masks"}
int	current			{prompt="The current mask number"}
int	nprev			{prompt="The number of previous masks to use"}
string	keyword			{prompt="The object mask keyword name"}
string	outmask			{prompt="The name of the output mask"}
string	outarg			{prompt="The return output argument"}

struct	*imglist

begin

	int	tcurrent, tnprev, nim, start, finish, ndiff
	string	tinmasks, tkeyword, toutmask, cobjlist, imlist, tmpname, img


	# Get query parameters.
	tinmasks = inmasks
	if (tinmasks == "") {
	    outarg = "1"
	    return
	}

	# Return if the current mask is less than or equal to one.
	tcurrent = current
	if (tcurrent <= 1) {
	    outarg = "1"
	    return
	}

	# Return if the number of previous masks is less than or equal to
	# zero.
	tnprev = nprev
	if (tnprev <= 0) {
	    outarg = "1"
	    return
	}
	tkeyword = keyword
	toutmask = outmask

	# Count the number of input masks / images
	count (tinmasks) | scan (nim)

	# Compute the mask range to be used and create the temporary list.
	start = max (1, tcurrent - tnprev)
	finish = min (nim, tcurrent - 1)
	ndiff = finish - start + 1

	# Sum the masks.
	if (ndiff > 0) {

	    # Create a file to contain the image sublist.
	    cobjlist = mktemp ("tmp$xaddmask")

	    # In this case the input list is the list of object masks which
	    # are extracted and summed.
	    nim = 0
	    if (tkeyword == "") {

	        xlist (tinmasks, cobjlist, start, finish, 0, suffix="")
		count (cobjlist) | scan (nim)

	    # In this case the input list is the list of parent images which
	    # contain the object mask keyword.

	    } else {
	        imlist = mktemp ("tmp$xaddmask")
	        xlist (tinmasks, imlist, start, finish, 0, suffix="")
		count (imlist) | scan (nim)
		if (nim > 0) {  
		    imglist = imlist
		    while (fscan (imglist, img) != EOF) {
		        tmpname = ""
		        hselect (img, tkeyword, yes) | scan (tmpname)
		        if (access(tmpname)) {
			    print (tmpname, >> cobjlist)
		        } else {
			    break
		        }
		    }
		}
	        delete (imlist, verify-)
	    }

	    # Extract and sum the masks.
	    if (nim != ndiff) {
		outarg = "1"
	    } else if (ndiff == 1) {
		fileroot (toutmask, validim+)
		tmpname = fileroot.root // ".pl"
		imcopy ("@" // cobjlist, tmpname, verbose-)
		outarg = tmpname
	    } else {
	        if (imaccess ("_junk.pl")) imdelete ("_junk.pl", verify-)
                imsum ("@" // cobjlist, "_junk.pl", title="", hparams="",
	            pixtype="", calctype="", option="sum", low_reject=0.0,
		    high_reject=0.0, verbose-) 
		fileroot (toutmask, validim+)
		tmpname = fileroot.root // ".pl"
	        imexpr ("a > 0 ? 1 : 0", tmpname, "_junk.pl", dims="auto",
		    intype="auto", outtype="auto", refim="auto", bwidth=0,
		    btype="nearest", bpixval=0.0, rangecheck=yes, verbose-,
		    exprdb="none")
	        imdelete ("_junk.pl", verify-)
		outarg = tmpname
	    }

	    if (access (cobjlist)) delete (cobjlist, verify-)

	} else {
	    outarg = "1"
	}

	imglist = ""
end
