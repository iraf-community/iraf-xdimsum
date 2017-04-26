# Register the input images using imcombine.

procedure xmskcombine (inlist, bpmask, crmasks, hmasks, omasks, rmasks)
	
string	inlist	 	{prompt="List of input sky subtracted images"}
string	bpmask	        {"", prompt="Input bad pixel file"}
string	crmasks		{"", prompt="Input CR mask keyword or CR mask list"}
string	omasks		{"", prompt="Input object mask keyword or object mask list"}
string	hmasks		{"", prompt="Input holes mask keyword or holes mask list"}
string	rmasks		{".rjm", prompt="The output combined rejection mask"}
int	nprev_omask	{0, prompt="Number of previous object masks to use"}


struct *simglist
struct *himglist
struct *crimglist
struct *oimglist
struct *rimglist

begin

int	nin, ncrm, nhom, nobm, imno, ixdim, iydim
string	tinlist, tbpmask, tcrmasks, thmasks, tomasks, trmasks
string	slist, clist, hlist, olist, rlist
string	img, tmpname, rmaskname
string	bparg, hmarg, crarg, omarg


# Get the query parameters.

	tinlist = inlist
	tbpmask = bpmask
	tcrmasks = crmasks
	thmasks = hmasks
	tomasks = omasks
	trmasks = rmasks

# Create the image names list

	slist = mktemp ("tmp$xnregistar")
	sections (tinlist, option="fullname", > slist)
	nin = sections.nimages
	if (nin <= 0) {
	    print ("The input sky subtracted image list is empty")
	    delete (slist, verify-)
	    return
	}

# Create the cosmic ray image list

	clist = mktemp ("tmp$xnregistar")
	sections (tcrmasks, option="fullname", > clist)
	ncrm = sections.nimages
	if (ncrm > 1 && (ncrm != nin)) {
	    print ("There are too few cosmic ray masks")
	    delete (clist, verify-)
	    delete (slist, verify-)
	    return
	}

# Create the holes image list

	hlist = mktemp ("tmp$xnregistar")
	sections (thmasks, option="fullname", > hlist)
	nhom = sections.nimages
	if (nhom > 1 && (nhom != nin)) {
	    print ("There are too few holes masks")
	    delete (hlist, verify-)
	    delete (clist, verify-)
	    delete (slist, verify-)
	    return
	}

# Create the object mask list.

	olist = mktemp ("tmp$xnregistar")
	sections (tomasks, option="fullname", > olist)
	nobm = sections.nimages
	if (nobm > 1 && (nobm != nin)) {
	    print ("There are too few object masks")
	    delete (olist, verify-)
	    delete (hlist, verify-)
	    delete (clist, verify-)
	    delete (slist, verify-)
	    return
	}

# Create the output rejected pixel mask list.

	rlist = mktemp ("tmp$xnregistar")
        if (substr (trmasks, 1, 1) == ".") {
            simglist = slist
            while (fscan (simglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // trmasks
                print (img, >> rlist)
            }
        } else {
            sections (trmasks, option="fullname", > rlist)
            if (nin != sections.nimages) {
                print ("Error: Input and output image lists do not match")
	        delete (rlist, verify-)
	        delete (olist, verify-)
	        delete (hlist, verify-)
	        delete (clist, verify-)
	        delete (slist, verify-)
                return
            }
        }

# Delete any pre-xisting masks for the input images.

	imdelete ("@" // rlist, verify-, >& "dev$null")

	print ("Creating individual composite masks ...")
	if (imaccess (tbpmask)) {
	    print ("Using bad pixel mask file: ", tbpmask)
	}


# Initialize the image loop.

	simglist = slist
	himglist = hlist
	crimglist = clist
	oimglist = olist
	rimglist = rlist
	imno = 0

# Now create the combined mask images required for imcombine.

# Treat the case of a defined bad pixel mask only as a special case
# by simply adding the bad pixel mask name to the REJMASK keyword.

	if (tbpmask != "" && nhom <= 0 && ncrm <= 0 && nobm <= 0) {

	    while (fscan (simglist, img) != EOF) {
	        print ("Creating rejection mask for image: ", img)
		print ("    Setting rejection mask to: ", tbpmask)
	        hedit (img, "REJMASK", tbpmask, ,add+, delete-, verify-,
		    show-, update+)
	    }

	} else {

	    while (fscan (simglist, img) != EOF) {

# Strip off extension if present.

	        fileroot (img, validim+)
	        img = fileroot.root
	        print ("Creating rejection mask for image: ", img)

	        imno = imno + 1

# Get the bad pixel mask argument.

	        if (imaccess (tbpmask)) {
		    bparg = tbpmask
	        } else {
		    bparg = "1"
	        }

# Get the holes mask argument.

	        if (thmasks == "") {
		    hmarg = "1"
	        } else {
		    tmpname = ""
	            hselect (img, thmasks, yes) | scan (tmpname)
	            if (tmpname != "") {
		        if (access (tmpname)) {
		            print ("    Using header holes mask file: ",
			        tmpname)
		            hmarg = tmpname
		        } else {
		            print ("    Cannot find holes mask file: ",
			        tmpname)
		            hmarg = "1"
		        }
	            } else if (fscan (himglist, tmpname) != EOF) {
	                if (access (tmpname)) {
		            print ("    Using holes mask file: ", tmpname)
		            hmarg = tmpname
		        } else if (nin > nhom) {
		            hmarg = "1"
		        } else {
		            print ("    Cannot find holes mask file: ", tmpname)
		            hmarg = "1"
		        }
	            } else {
		        hmarg = "1"
	            }
	        }


# Get the cosmic ray mask argument.

	        if (tcrmasks == "") {
		    crarg = "1"
	        } else {
		    tmpname = ""
	            hselect (img, tcrmasks, yes) | scan (tmpname)
	            if (tmpname != "") {
		        if (access (tmpname)) {
		            print ("    Using header cr mask file: ", tmpname)
		            crarg = tmpname
		        } else {
		            print ("    Cannot find cr mask file: ", tmpname)
		            crarg = "1"
		        }
	            } else if (fscan (crimglist, tmpname) != EOF) {
	                if (access (tmpname)) {
		            print ("    Using crmask file: ", tmpname)
		            crarg = tmpname
		        } else if (nin > ncrm) {
		            crarg = "1"
		        } else {
		            print ("    Cannot find cr mask file: ", tmpname)
		            crarg = "1"
		        }
	            } else {
		        crarg = "1"
	            }
	        }

# Get the object mask argument.

	        if (nprev_omask <= 0 || tomasks == "") {
		    omarg = "1"
	        } else {
		    tmpname = ""
	            hselect (img, tomasks, yes) | scan (tmpname)
		    if (imaccess ("_objmask.pl"))
		        imdelete ("_objmask.pl", verify-)
	            if (tmpname != "") {
		        xaddmask (slist, imno, nprev_omask, tomasks,
			    "_objmask.pl")
		        if (xaddmask.outarg == "1") {
		            print ("    Cannot find object mask files ")
		            omarg = "1"
		        } else {
		            print ("    Using previous mask files")
			    omarg = "_objmask.pl"
		        }
		    } else {
		        xaddmask (olist, imno, nprev_omask, "", "_objmask.pl")
		        if (xaddmask.outarg == "1") {
		            print ("    Cannot find object mask files ")
		            omarg = "1"
		        } else {
		            print ("    Using previous mask files")
			    omarg = "_objmask.pl"
		        }
		    } 
	        }

# Get the output composite mask name and delete any existing image of the
# same name.

		rmaskname = ""
	        if (fscan (rimglist, rmaskname) == EOF)
		    break
		fileroot (rmaskname, validim+)
		rmaskname = fileroot.root // ".pl"
	        if (imaccess (rmaskname))
		    imdelete (rmaskname, verify-)

# Create the composite mask. Good data values will have a mask value of 1,
# bad values a mask value of 0.

	        if (bparg == "1" && hmarg == "1" && crarg == "1" &&
		    omarg == "1") {
		    hselect (img, "i_naxis1", yes) | scan (ixdim)
		    hselect (img, "i_naxis2", yes) | scan (iydim)
		    imexpr ("repl(a,b)", rmaskname, "1", ixdim, dims="auto",
		        intype="auto", outtype="auto", dims=ixdim//","//iydim,
		        refim="auto", bwidth=0, btype="nearest", bpixval=0.0,
		        rangecheck=yes, verbose=no, exprdb="none")
	        } else if (crarg == "1" && omarg == "1") {
		    imexpr ("a * b", rmaskname, bparg, hmarg, dims="auto",
		        intype="auto", outtype="auto", refim="auto", bwidth=0,
		        btype="nearest", bpixval=0.0, rangecheck=yes,
		        verbose=no, exprdb="none")
	        } else if (crarg == "1") {
		    imexpr ("d == 1 ? 0 : a * b", rmaskname, bparg,
		        hmarg, crarg, omarg, dims="auto", intype="auto",
		        outtype="auto", refim="auto", bwidth=0, btype="nearest",
		        bpixval=0.0, rangecheck=yes, verbose=no, exprdb="none")
	        } else if (omarg == "1") {
		    imexpr ("c == 1 ? 0 : a * b", rmaskname, bparg,
		        hmarg, crarg, omarg, dims="auto", intype="auto",
		        outtype="auto", refim="auto", bwidth=0, btype="nearest",
		        bpixval=0.0, rangecheck=yes, verbose=no, exprdb="none")
	        } else {
		    imexpr ("c == 1 || d == 1 ? 0 : a * b", rmaskname, bparg,
		        hmarg, crarg, omarg, dims="auto", intype="auto",
		        outtype="auto", refim="auto", bwidth=0, btype="nearest",
		        bpixval=0.0, rangecheck=yes, verbose=no, exprdb="none")
	        }

	        if (imaccess("_objmask.pl")) imdelete ("_objmask.pl", verify-)

	        hedit (img, "REJMASK", rmaskname, ,add+, delete-, verify-,
		    show-, update+)
	    }
	}


# Cleanup.

	delete (olist, verify-)
	delete (hlist, verify-)
	delete (clist, verify-)
	delete (slist, verify-)
	delete (rlist, verify-)

	simglist = ""
	himglist = ""
	crimglist = ""
	oimglist = ""
	rimglist = ""
end
