# Sky subtract a list of images  using a running mean frame, akin to a local
# sky flatfield. 
#
# Sky frames are scaled by their median values before combining. Medians are
# used because the data is unflattened. The image medians are computed by
# the rskysub task. The computed median is written into the SKYMED header
# keyword. If a SKYMED keyword already exists then the median is not recomputed
# unless the forcescale parameter is enabled.
#
# Boolean parameter usomasks determines if scaling of images by their medians
# excludes masked regions. For cases where variation due to  objects exceeds
# the residual flatfield variation in the input images, this parameter should
# be yes.  For dim objects and noticeable residual flatfield problems it should
# be no.  Note that even with useomask=no rskysub will mask out pixels.


procedure xnslm (inlist, omasks, nmean, outlist)

# Calls the xdimsum tasks rskysub.

# Also calls the tasks sections and delete and the CL builtin tasks mktemp. 

string	inlist	     {prompt="List of input images to be sky subtracted"}
string	omasks	     {"", prompt="The input object mask keyword or list"}
int	nmean        {min=1,prompt="Number of images to use to make sky frame"}
string 	outlist	     {".sub", prompt="The output sky subtracted images or suffix"}
string 	hmasks	     {".hom", prompt="The output holes masks or suffix"}

bool	forcescale  {no,  prompt="Force recalculation of input image medians ?"}
bool	useomask    {no,  prompt="Use object masks to compute input image medians ?"}
string	statsec	    {"", prompt="The sky statistics image section"}
real	nsigrej	    {3.0, prompt="The nsigma sky statistics rejection limit"}
int	maxiter	    {20, prompt="The maximum number of sky statistics iterations"}
int	nskymin     {3, min=0, prompt="The minimum number of frames to use for sky"}
int	nreject     {1, min=0, prompt="The number of high and low side pixels to reject"}

bool	cache       {yes, prompt="Attempt to cache images in memory ?"}	
bool 	del_hmasks  {no, prompt="Delete holes masks on task termination ?"}

struct	*imglist


begin
	string imlist, omsklist, outimlist, hmsklist
	string tomasks, toutlist, thmasks, img
	int nin, nomasks, tnmean, nsmin


# Make temporary files.

	imlist  = mktemp ("tmp$xnslm") 
	omsklist  = mktemp ("tmp$xnslm") 
	outimlist  = mktemp ("tmp$xnslm") 
	hmsklist  = mktemp ("tmp$xnslm") 

# Get query parameters and initialize

	sections (inlist, option="fullname", > imlist)
	nin = sections.nimages
	tnmean = nmean

	tomasks = omasks
        sections (tomasks, option="fullname", > omsklist)
	nomasks = sections.nimages
	if (tomasks == "") {
	    useomask = no
        } else if (nomasks > 0) {
            if (nomasks > 1 && nin != nomasks) {
                print ("Input and object mask image lists do not match")
		delete (imlist, ver-)
		delete (omsklist, ver-)
                return
            }
        } else {
	    useomask =  no
        }

	toutlist = outlist
        if (substr (toutlist, 1, 1) == ".") {
            imglist = imlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // toutlist
                print (img, >> outimlist)
            }
        } else {
            sections (toutlist, option="fullname", > outimlist)
            if (nin != sections.nimages) {
                print ("Error: Input and cosmic ray image lists do not match")
                delete (imlist, ver-)
                delete (outimlist, ver-)
                delete (omsklist, ver-)
                return
            }
        }

	thmasks = hmasks
        if (substr (thmasks, 1, 1) == ".") {
            imglist = outimlist
            while (fscan (imglist, img) != EOF) {
                fileroot (img, validim+)
                img = fileroot.root // thmasks
                print (img, >> hmsklist)
            }
        } else {
            sections (thmasks, option="fullname", > hmsklist)
            if (nin != sections.nimages) {
                print ("Error: Input and holes mask image lists do not match")
                delete (imlist, ver-)
                delete (outimlist, ver-)
                delete (omsklist, ver-)
                delete (hmsklist, ver-)
                return
            }
        }

# Check the value of nskymin.

	if (nskymin > tnmean) {
	    print ("Parameter nskymin must be <= nmean")
	    delete (imlist, ver-)
	    delete (omsklist, ver-)
            delete (outimlist, ver-)
	    delete (hmsklist, ver-)
	    return
	} else if (nskymin == 0) {
	    nsmin = tnmean
	} else {
	    nsmin = nskymin
	}


# Call the rskysub task.

	rskysub ("@" // imlist, "@" // outimlist, imasks="@" // omsklist,
	    omasks="", hmasks= "@" // hmsklist, rescale=forcescale,
	    scale="median", useimasks=useomask, skyscale="SKYMED",
	    statsec=statsec, lower=INDEF, upper=INDEF, maxiter=maxiter,
	    lnsigrej=nsigrej, unsigrej=nsigrej, binwidth=0.1,
	    resubtract=yes, combine="average", ncombine=tnmean, nmin=nsmin,
	    nlorej=nreject, nhirej=nreject, blank=0, skysub="SKYSUB",
	    holes="HOLES", cache=cache, verbose=yes)

# Cleanup.

	delete (imlist, ver-)
	delete (omsklist, ver-)
	delete (outimlist, ver-)
	if (del_hmasks) {
	    imdelete ("@" // hmsklist, verify-, >& "dev$null")
	}
	delete (hmsklist, ver-)

	imglist = ""
end
