# Clean cosmic rays from images using median filtering.

procedure xzap (inlist, omasks, outlist, crmasks)

# Calls xdimsum scripts fileroot.cl, iterstat.cl, makemask.cl, minv.cl
#
# Also calls sections, minmax, fmedian, imarith, imcopy, imdelete, imreplace,
# imexpr, boxcar, hedit, and delete tasks.
#
# If omasks is defined then the input object mask is used to unzap cosmic
# rays in object regions. This object mask must be the inverse of the
# usual object mask, i.e. pixels in object regions are 0's, pixels elsewhere
# are 1's. In xdimsum the object mask is usually stored in the keyword
# CROBJMAS.
#
# The name of the output cosmic ray mask is written into the keyword 
# CRMASK in both the input and the output images.

string	inlist	    {prompt="List of input images to be cosmic ray cleaned"}
string	omasks      {"", prompt="The input object mask keyword or list"}
string	outlist	    {prompt="List of output cosmic ray cleaned images"}
string	crmasks     {".crm", prompt="The output cosmic ray masks or suffix"}

string	statsec	    {"",prompt="Image section to use for computing sky sigma"}
real	nsigrej	    {3.0, prompt="The n-sigma sky rejection parameter"}
int	maxiter	    {20, prompt="The maximum number of iterations"}

bool	checklimits {yes,prompt="Check min and max pix values before filtering?"}
int	zboxsz	    {5,min=3,prompt="Box size for fmedian filter"}
real	zmin        {-32768.0,prompt="Minimum data value for fmedian filter"}
real	zmax        {32767.0,prompt="Maximum data value for fmedian filter"}

real	nsigzap	    {5.0,min=0.,prompt="Zapping threshold in number of sky sigma"}

real	nsigobj     {2.0,min=0.,prompt="Number of sky sigma for object identification"}
int	subsample   {1,min=0,prompt="Block averaging factor before median filtering"}
int     skyfiltsize {15,min=0,prompt="Median filter size for local sky evaluation"}
int	ngrowobj    {0,min=0,prompt="Number of pixels to flag as buffer around objects"}

int	nrings	    {0,min=0,prompt="Number of pixels to flag around CRs"}

real	nsigneg     {0.0,min=0.,prompt="Number of sky sigma for negative zapping"}

bool	del_crmask  {no, prompt="Delete cosmic ray mask after execution?"}
bool	del_wimages {yes,prompt="Delete working images after execution?"}
bool	del_wmasks  {yes,prompt="Delete working .pl masks after execution?"}

bool	verbose     {yes,prompt="Verbose output?"}

struct	*imglist
struct	*outimglist
struct	*omskimglist
struct	*crmskimglist

begin
	real	skysig, skymode, crthresh, objthresh, negthresh, dmin, dmax
	int	nomasks, nbox, nbox2, nin
	string 	infile, maskfile, omskfile, crmskfile, outfile, tomasks
	string	tcrmasks, img, outimg, crimg, ext, oext
	bool	maskobj, dounzap, maskneg

# Expand file lists into temporary files.

	infile =  mktemp ("tmp$xzap")
	outfile = mktemp ("tmp$xzap")
	omskfile = mktemp ("tmp$xzap")
	crmskfile = mktemp ("tmp$xzap")

	sections (inlist, option="fullname", > infile)
	nin = sections.nimages

	tomasks = omasks
	sections (tomasks, option="fullname", > omskfile)
	nomasks = sections.nimages
	if (tomasks == "") {
	    dounzap = no
	} else if (nomasks > 0) {
	    if (nomasks > 1 && nin != nomasks) {
	        print ("Error: Input and object mask image lists do not match")
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

	sections (outlist, option="fullname", > outfile)
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

# Check input parameters.

	if (nsigobj <= 0.0) {
	    print ("Warning: No internal object masking will be done in xzap")
	    maskobj = no
	} else {
	    maskobj = yes
	}
	if (nsigneg > 0.0) 
	    maskneg = yes 
	else 
	    maskneg = no

	imglist = infile
	outimglist = outfile
	omskimglist = omskfile
	crmskimglist = crmskfile

# Loop through input files:

	while (fscan (imglist,img) != EOF && fscan (crmskimglist,
	    crimg) != EOF) {

# Strip extension off input file name.

	    fileroot (img, validim+)
	    img = fileroot.root
	    ext = fileroot.extension
	    if (ext != "")
		ext = "." // ext

	    fileroot (crimg, validim+)
	    crimg = fileroot.root // ".pl"


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

# Calculate sky mean and RMS noise using iterative sigma rejection.

	    if (verbose) print ("    Computing image statistics")
	    iterstat (img // ext, statsec=statsec, nsigrej=nsigrej,
	        maxiter=maxiter, lower=INDEF, upper=INDEF, show-)
	    skymode = iterstat.imean
	    skysig  = iterstat.isigma

# Median filter image to produce file _fmedtemp

	    if (verbose) print ("    Median filtering")

# First, check limits of data range. Wildly large (positive or negative) data
# values will screw up fmedian calculation unless checklimits = yes and zmin
# and zmax are set to appropriate values, e.g. zmin=-32768, zmax=32767. Note
# that the old fmedian bug which occurred if zmin=hmin and zmax=hmax has been
# fixed in IRAF version 2.10.1. The pipe to dev$null however is included
# because V2.10.1 and .2 have debugging print statements accidentally left in
# the fmedian code.  

	    if (imaccess ("_fmedtemp")) imdelete ("_fmedtemp", ver-)
	    if (checklimits) {
		minmax (img // ext, force+, update+, ve-)
		if (verbose) {
		    print("    Data minimum = ", minmax.minval,
			" maximum = ", minmax.maxval)
		}
	        if (minmax.minval < zmin || minmax.maxval > zmax) {
		    if (minmax.minval < zmin) {
		        dmin = zmin
		    } else { 
		        dmin = minmax.minval
		    }
		    if (minmax.maxval > zmax) {
		        dmax = zmax
		    } else { 
		        dmax = minmax.maxval
		    }
		    if (verbose) {
		        print ("    Truncating data range ",dmin," to ",dmax)
		    }
		    fmedian (img // ext, "_fmedtemp", zboxsz, zboxsz,
		        hmin=-32768, hmax=32767, zmin=dmin, zmax=dmax,
			zloreject=INDEF, zhireject=INDEF, unmap+,
			boundary="reflect", constant=0.0, verbose-)
		} else {
		    fmedian (img // ext, "_fmedtemp", zboxsz, zboxsz,
		        hmin=-32768, hmax=32767, zmin=INDEF, zmax=INDEF,
			zloreject=INDEF, zhireject=INDEF, unmap+,
			boundary="reflect", constant=0.0, verbose-)
		}
	    } else {
		fmedian (img // ext, "_fmedtemp", zboxsz, zboxsz,
		    hmin=-32768, hmax=32767, zmin=INDEF, zmax=INDEF,
		    zloreject=INDEF, zhireject=INDEF, unmap+,
		    boundary="reflect", constant=0.0, verbose-)
	    }

# Take difference to produce "unsharp masked" image _crtemp

	    if (imaccess ("_crtemp")) imdelete ("_crtemp", ver-)
	    imarith (img // ext, "-", "_fmedtemp", "_crtemp", title="",
	        divzero=0.0, hparams="", pixtype="", calctype="", verbose-,
		noact-)

# Threshold _crtemp at nsigzap * skysig to make CR masks _peakstemp.  
#    Potential CRs --> 1
#    Blank sky --> 0
# Note that crthresh will be positive by definition.

	    if (verbose) print ("    Masking potential CR events")
	    if (imaccess ("_peakstemp" // ".pl"))  {
	        imdelete ("_peakstemp" // ".pl", ver-)
	    }
	    crthresh = nsigzap * skysig   
	    imexpr ("a >= b ? 1 : 0", "_peakstemp" // ".pl", "_crtemp",
	        "" // crthresh, dims="auto", intype="auto", outtype="int",
		refim="auto", rangecheck=yes, bwidth=0, btype="nearest",
		bpixval=0.0, exprdb="none", verbose-)

# Object masking:  create mask identifying where objects might be.

	    if (imaccess (crimg)) {
		imdelete (crimg, ver-)
	    }
	    if (maskobj) {

		if (verbose) print ("    Creating object mask")
		objthresh = nsigobj * skysig  

	        if (imaccess ("_objfmedtemp" // ".pl")) {
		    imdelete ("_objfmedtemp" // ".pl", ver-)
		}
		makemask ("_fmedtemp", "_objfmedtemp" // ".pl",
		    hinlist="", subsample=subsample, filtsize=skyfiltsize,
		    nsmooth=0, statsec=statsec, nsigrej=nsigrej,
		    maxiter=maxiter, threshtype="constant", nsigthresh=2.0,
		    constth=objthresh, negthresh=no, ngrow=ngrowobj,
		    checklimits=checklimits, zmin=-32767, zmax=32767, verbose-)

# Invert mask to make "objects" --> 0 and "sky" --> 1.
		minv ("_objfmedtemp" // ".pl", "_objfmedtemp" // ".pl")

# If not masking objects, final CR mask is just _peakstemp.  If we are
# masking objects, take product of object and CR masks to make crm_//img

		imarith ("_peakstemp" // ".pl", "*",
		    "_objfmedtemp" // ".pl", crimg,  title="",
		    divzero=0.0, hparams="", pixtype="", calctype="",
		    verbose-)
	    } else {
		imcopy ("_peakstemp" // ".pl", crimg, verbose-)
	    }

# Grow additional buffer region around identified CRs.

	    if (nrings > 0) {
		if (verbose) print ("    Growing mask rings around CR hits")
		nbox = 2 * nrings + 1
		nbox2 = nbox * nbox
		imarith (crimg, "*", nbox2, crimg, title="", divzero=0.0,
		    hparams="", pixtype="", calctype="", verbose-)
		boxcar (crimg, crimg, nbox, nbox, boundary=nearest,
		    constant=0.0)
		imreplace (crimg, 1, lower=1, upper=INDEF, radius=0.0)
	    }

# Identify negative pixels if desired.  No "rings" are grown around negative 
# pixels.

	    if (maskneg) {
		if (verbose) print ("     Masking deviant negative pixels")
	        if (access ("_negtemp" // ".pl")) {
		    delete ("_negtemp" // ".pl", ver-)
		}
		negthresh = -1. * nsigneg * skysig
	        imexpr ("a >= b ? 1 : 0", "_negtemp" // ".pl",
		    "_crtemp", "" // negthresh, dims="auto", intype="auto",
		    outtype="int", refim="auto", rangecheck=yes, bwidth=0,
		    btype="nearest", bpixval=0.0, exprdb="none", verbose-)
		imarith (crimg, "+", "_negtemp" // ".pl", crimg,
		    title="", divzero=0.0, hparams="", pixtype="",
		    calctype="", verbose-, noact-)
		imreplace (crimg, 1, lower=1, upper=INDEF, radius=0.0)
	    }

# Unzap pixels which are where objects are as defined by objmask files

            if  (dounzap) {
	        if (verbose) print ("    Unzapping CRs which are object pixels")
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
		if (maskfile != "")
                    imarith (maskfile, "*", crimg, crimg, title="", divzero=0.0,
		        hparams="", pixtype="", calctype="", ver-, noact-)
            }

# Remove processing keywords from the cosmic ray mask.

	    hedit (crimg, "SKYMED,SKYSUB,MASKFIX", "", add-, del+,
	        ver-, show-, update+, >& "dev$null")

# Multiply CR mask by crm_//img to make "comic rays only" image _cronlytmp
# Could combine two imarith statements into 1 imexpr call except for the
# option of keeping the _cronlytemp image.

	    if (verbose) print ("    Replacing CR hits with local median")
	    if (imaccess ("_cronlytemp")) imdelete ("_cronlytemp", ver-)
	    imarith ("_crtemp", "*", crimg, "_cronlytemp", title="",
	        divzero=0.0, hparams="", pixtype="", calctype="", ver-, noact-)

# Subtract _cronlytemp from data to produce clean image "outimg". Note that
# this effectively replaces the masked regions with the local median, since
# _cronlytemp = img - _fmedtemp.

	    imarith (img // ext, "-" , "_cronlytemp", outimg // oext,
	        title="", divzero=0.0, hparams="", pixtype="", calctype="",
		ver-, noact-)

# Record CR mask name in headers of input and output images

	    hedit (img // ext // "," // outimg // oext, "CRMASK", crimg, add+,
	        ver-, show-, update+, >& "dev$null")

# Clean up.
	    if (del_crmask) delete (crimg, verify-)
	    if (del_wmasks) {
		delete ("_peakstemp" // ".pl", ve-)
		if (maskobj) delete ("_objfmedtemp" // ".pl", ve-)
		if (maskneg) delete ("_negtemp" // ".pl", ve-)
	    }
	    if (del_wimages) {
		imdelete ("_fmedtemp", ve-)
		imdelete ("_crtemp", ve-)
		imdelete ("_cronlytemp", ve-)
	    }
	    if (verbose) print ("    Done")
	}

	imglist = ""; delete (infile, verify-)
	outimglist = ""; delete (outfile, verify-)
	omskimglist = ""; delete (omskfile, verify-)
	crmskimglist = ""; delete (crmskfile, verify-)
end
