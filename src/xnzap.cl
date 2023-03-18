# Clean cosmic rays from images using an average filter.

procedure xnzap (inlist, omasks, outlist, crmasks)

string	inlist	      {prompt="The list of input images to be cosmic ray cleaned"}
string	omasks        {"", prompt="The input object mask keyword or name"}
string	outlist	      {prompt="The output image list of cosmic ray cleaned images"}
string	crmasks        {".crm", prompt="The output cosmic rays masks of suffix"}

int	zboxsz	      {5,min=3,prompt="Box size for averaging filter"}
int     skyfiltsize   {15,min=0,prompt="Median filter size for local sky evaluation"}
int     sigfiltsize   {25,min=0,prompt="Percentile filter size for local sigma evaluation"}

real	nsigzap	      {5.0,min=0.,prompt="Positive zapping threshold in number of sky sigma"}
real	nsigneg       {0.0,min=0.,prompt="Negative zapping threshold in number of sigma"}
int	nrejzap	      {1,min=0,prompt="Number of high pixels to reject from averaging filter"}
int	nrings	      {0,min=0,prompt="Number of pixels to flag around CRs"}

real	nsigobj       {5.0,min=0.,prompt="Number of sky sigma for object identification"}
int	ngrowobj      {0,min=0,prompt="Number of pixels to flag as buffer around objects"}

bool	del_crmask    {no, prompt="Delete cosmic ray mask after execution?"}
bool	verbose       {yes,prompt="Verbose output?"}

struct	*imglist
struct	*outimglist
struct	*omskimglist
struct  *crmskimglist

begin
	real lcrsig, hcrsig, crgrow, lobjsig, hobjsig, objgrow
	int nin, nomasks, navg, nbkg, nsig, nrej
	bool dounzap
	string tomasks, maskfile, infile, outfile, omskfile, img, outimg, str1
	string tcrmasks, crmskfile, ext, oext, crimg

# Expand input image lists into temporary files.

	infile =  mktemp ("tmp$xnzap")
	outfile = mktemp ("tmp$xnzap")
	omskfile = mktemp ("tmp$xnzap")
	crmskfile = mktemp ("tmp$xnzap")

	sections (inlist, option="fullname", >infile)
	nin = sections.nimages

        tomasks = omasks
        sections (tomasks, option="fullname", > omskfile)
        nomasks = sections.nimages
        if (tomasks == "") {
	    dounzap = no
        } else if (nomasks > 0) {
            if (nomasks > 1 && nin != nomasks) {
                print ("Input and object mask image lists do not match")
                delete (infile, ver-)
                delete (outfile, ver-)
                delete (omskfile, ver-)
	        delete (crmskfile, ver-)
                return
            } else {
                dounzap = yes
            }
        } else {
	    dounzap = no
        }

	sections (outlist, option="fullname", >outfile)
	if (nin != sections.nimages) {
	    print ("Error: Input and output image lists do not match")
	    delete (infile, ver-)
	    delete (outfile, ver-)
	    delete (omskfile, ver-)
	    delete (crmskfile, ver-)
	    return
	}

        tcrmasks = crmasks
        if (substr (tcrmasks, 1, 1) == ".") {
            imglist = outfile
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // tcrmasks // ".pl"
                print (img, >> crmskfile)
            }
        } else {
            sections (tcrmasks, option="fullname", > crmskfile)
            if (nin != sections.nimages) {
                print ("Error: Input and cosmic ray image lists do not match")
                delete (infile, ver-)
                delete (outfile, ver-)
                delete (omskfile, ver-)
                delete (crmskfile, ver-)
                return
            }
        }

# Define the filtering parameters.

	navg = zboxsz
	nbkg = max (1, (skyfiltsize - zboxsz) / 2)
	nsig = sigfiltsize
	nrej = nrejzap

# Define the cosmic ray detection parameters.

	if (nsigzap <= 0)
	    hcrsig = 65537.0
	else
	    hcrsig = nsigzap
	if (nsigneg <= 0.0)
	    lcrsig = 65537.0
	else
	    lcrsig = nsigneg
	crgrow = nrings

# Define the object detection parameters.

	if (nsigobj <= 0)
	    hobjsig = 65537.0
	else
	    hobjsig = nsigobj
	lobjsig = 65537.0
	objgrow = ngrowobj

	imglist = infile
	outimglist = outfile
	omskimglist = omskfile
	crmskimglist = crmskfile

# Loop through input files.

	while (fscan (imglist, img) != EOF && fscan (crmskimglist,
	    crimg) != EOF) {

# Strip extension off input file name.

	    fileroot (img, validim+)
	    img = fileroot.root
	    ext = fileroot.extension
	    if (ext != "")
		ext = "." // ext

# Read name of output file.

	    if (fscan (outimglist, outimg) == EOF) {
		print ("Error:  Cannot find output image name in xzap")
		imglist = ""; delete (infile, verify-)
		outimglist = ""; delete (outfile, verify-)
		omskimglist = ""; delete (omskfile, verify-)
		return
	    }

# Strip extension off output file name.

	    fileroot (outimg, validim+)
	    outimg = fileroot.root
	    oext = fileroot.extension
	    if (oext != "")
		oext = "." // oext

# Check the cosmic ray image name.

	    fileroot (crimg, validim+)
	    crimg = fileroot.root // ".pl"

# Check for existence and status of the output image.

	    if ( ! imaccess (outimg // oext)) {
	        print ("Creating cosmic ray corrected image ", outimg)
	    } else if (img // ext == outimg // oext) {
		imgets (outimg // oext, "CRMASK", >& "dev$null")
		if (imgets.value == "0") {
	            print ("Creating cosmic ray corrected image ", outimg)
		} else {
	            print ("Image ", outimg,
		        " has already been cosmic ray corrected")
		    next
		}
	    } else {
	        print ("Image ", outimg, " already exists")
		next
	    }


	    if (imaccess (crimg)) {
		imdelete (crimg, verify-)
	    }

# Get the mask file if any

	    if (dounzap) {
                maskfile = ""
                hselect (img // ext, tomasks, yes) | scan (maskfile)
                if (maskfile != "") {
                    if (access (maskfile)) {
                        print ("    Using header object mask : ", maskfile)
                    } else {
                        print ("    Cannot find object mask: ", maskfile)
                        maskfile = ""
                    }
                } else if (fscan (omskimglist, maskfile) != EOF) {
                    if (access (maskfile)) {
                        print ("    Using object mask : ", maskfile)
                    } else if (nin > nomasks) {
                        maskfile = ""
                    } else {
                        print ("    Cannot find object mask: ", maskfile)
                        maskfile = ""
                    }
                } else {
                    maskfile = ""
                }
		if (maskfile != "") {
		    minv (maskfile, crimg)
		}
	    } else {
                maskfile = ""
	    }

# Detect the cosmic rays.

	    if (img // ext == outimg // oext) {
		str1 = "_out_" 
		if (oext != "")
		    str1 = str1 // oext
	        craverage (img // ext, str1, crmask=crimg, average="",
		    sigma="", navg=navg, nrej=nrej, nbkg=nbkg,
		    nsig=sigfiltsize, var0=0.0, var1=0.0, var2=0.0, crval=1,
		    lcrsig=lcrsig, hcrsig=hcrsig, crgrow=crgrow, objval=0,
		    lobjsig=lobjsig, hobjsig=hobjsig, objgrow=objgrow)
		imdelete (img // ext, verify-)
		imrename (str1, outimg // oext, verbose-)
		
	    } else {
	        craverage (img // ext, outimg // oext, crmask=crimg,
		    average="", sigma="", navg=navg, nrej=nrej, nbkg=nbkg,
		    nsig=sigfiltsize, var0=0.0, var1=0.0, var2=0.0, crval=1,
		    lcrsig=lcrsig, hcrsig=hcrsig, crgrow=crgrow, objval=0,
		    lobjsig=lobjsig, hobjsig=hobjsig, objgrow=objgrow)
	    }

	    if (dounzap && maskfile != "") {
                imarith (maskfile, "*", crimg, crimg, title="", divzero=0.0,
                    hparams="", pixtype="", calctype="", ver-, noact-)
	    }


# Record CR mask name in headers of input and output images.

	    hedit (img // ext // "," // outimg // oext, "CRMASK", crimg, add+,
	        ver-, show+, update+, >& "dev$null")

# Clean up.
	    if (del_crmask) delete (crimg, verify-)
	    if (verbose) print ("    Done")
	}

	imglist = ""; delete (infile, verify-)
	outimglist = ""; delete (outfile, verify-)
	omskimglist = ""; delete (omskfile, verify-)
	crmskimglist = ""; delete (crmskfile, verify-)
end
