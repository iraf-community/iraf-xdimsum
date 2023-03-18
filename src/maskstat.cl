# Calculate images statistics from unmasked regions of an input frame.

procedure maskstat (inlist, masks, goodvalue)

# The mask file must have only values of 0 and 1. No error checking is 
# presently done for this.
#
# Parameter iterstat gives the option of calling iterative statistics
# routine iterstat instead of imstat.   
#
# Mask stat checks to see if stsdas.tools is loaded.  If so, it uses
# imcalc to do the calculation;  otherwise, it uses a slower combination of
# imarith statements.
#
# Maskstat uses the dimsum tasks iterstat.cl, minv.cl, and fileroot.cl.
#
# Maskstat also uses sections, imarith, imdelete, and delete.

string	inlist   	{prompt="The input image list"}
string	masks    	{prompt="The input mask list"}
int	goodvalue	{0,min=0,max=1,prompt="Good pixel value in mask"}
string	statsec		{"", prompt="The section for computing statistics"}
real    lower		{INDEF,prompt="Initial lower limit for data range"}
real    upper		{INDEF,prompt="Initial upper limit for data range"}
bool	iterstat	{no,prompt="Use iterstat instead of imstat ?"}
real	nsigrej		{3.0, prompt="The n-sigma rejection limit"}
int	maxiter		{20, prompt="The maximum number of iterations"}
bool	show	 	{yes,prompt="Print results of final iteration ?"}
real	mean		{prompt="The returned masked mean value"}
real	msigma		{prompt="The returned masked sigma value"}
real	median		{prompt="The returned masked median value"}
real	mmode		{prompt="The returned masked mode value"}

struct	*imglist
struct	*mlist

begin

# Declare local variables.

	real	mn, sig, med, mod
	int	nimgs, nmask, goodv, npx
	string	imginlist, img, msk, infile, mfile, mlistf

# Get query parameter.

	imginlist = inlist
	msk = masks
	goodv = goodvalue

# Expand input image list.

	infile = mktemp ("tmp$maskstat")
	sections (imginlist, option="fullname", > infile)
	nimgs = sections.nimages
	imglist = infile

# Expand mask image list.

	sections (msk, option="nolist")
	nmask = sections.nimages
	if (nmask == 1) {
	    mfile = msk
	} else {
	    if (nmask != nimgs) {
		print ("ERROR: Numbers of image files and mask files differ.")
	        delete (infile, ver-)
		return
	    }
	    mlistf = mktemp ("tmp$maskstat")
	    sections (msk, option="fullname", >> mlistf)
	    mlist = mlistf
	}

# Loop through input image list.

	while (fscan (imglist, img) != EOF) {

# Get name of mask file if nmask > 1. If nmask == 1 it was defined above.

	    if (nmask != 1) {
		if (fscan (mlist, mfile) == EOF) {
	            delete (infile, ver-)
	    	    delete (mlistf, ver-)
		    print ("ERROR: Prematurely reached end of mask list.")
		    return
		}
	    }

# Calculate statistics for the mask file.

	    if (show) {
	        print ("Calculating statistics for ", img, " using mask ",
		    mfile)
	    }

	    if (iterstat) {
		if (goodv == 0)
		    miterstat (img, inmsklist=mfile, statsec=statsec,
		        nsigrej=nsigrej, maxiter=maxiter, lower=INDEF,
			upper=iNDEF, show=show)
		else {
		    miterstat (img, inmsklist="^"//mfile, statsec=statsec,
		        nsigrej=nsigrej, maxiter=maxiter, lower=INDEF,
			upper=iNDEF, show=show)
		}
		maskstat.mean = miterstat.imean
		maskstat.msigma = miterstat.isigma
		maskstat.median = miterstat.imedian
		maskstat.mmode = miterstat.imode
	    } else {
		if (goodv == 0)
		    mimstatistics (img // statsec, imasks=mfile, omasks="",
		        fields="mean,stddev,npix,midpt,mode", lower=INDEF,
		        upper=INDEF, binwidth=0.10, nclip=0, lsigma=3.0,
		        usigma=3.0, format-, cache-) | scan (mn, sig, npx,
		        med, mod)
		else {
		    mimstatistics (img // statsec, imasks="^"//mfile, omasks="",
		        fields="mean,stddev,npix,midpt,mode", lower=INDEF,
		        upper=INDEF, binwidth=0.10, nclip=0, lsigma=3.0,
		        usigma=3.0, format-, cache-) | scan (mn, sig, npx,
		        med, mod)
		}
		if (show) 
                   print (img, statsec, ":  mn=", mn, " rms=", sig,
		       " npix=", npx, "  med=", med, " mode=", mod)
		maskstat.mean = mn
		maskstat.msigma = sig
		maskstat.median = med
		maskstat.mmode = mod
	    }
	}

# Cleanup.

	if (nmask > 1) 
	    delete (mlistf, ver-)
	delete (infile, ver-)

	imglist = ""
	mlist = ""
end	
