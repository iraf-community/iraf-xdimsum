# ITERSTAT iteratively compute image statistics using the new IMSTATISTICS
# task. 


procedure iterstat (inlist)

# Iterstat also uses the mktemp, sections, and delete tasks.

file	inlist	{prompt="The input image list"}
string	statsec	{"", prompt="The image section for computing statistics"}
real	lower	{INDEF,prompt="The initial lower data limit"}
real	upper	{INDEF,prompt="The initial upper data limit"}
real	nsigrej	{3.0, min=0.0, prompt="The n-sigma rejection limit"}
int	maxiter	{20, min=1, prompt="The maximum number of iterations"}
bool	show	{yes, prompt="Print final results ?"}
real	imean	{prompt="The returned image mean"}
real	isigma	{prompt="The returned image sigma"}
real	imedian	{prompt="The returned image median"}
real	imode	{prompt="The returned image mode"}

struct	*imglist
struct	*seclist

begin

# Declare local variables.
real	mn, sig, med, mod
int	npx
string	imginlist, infile, secfile, img, sec, usec

# Get query parameter.
	imginlist = inlist

# Expand image template into a list of root image names.
	infile =  mktemp ("tmp$iterstat")
	sections (imginlist, option="root", > infile)

# Expand image template into a list of image sections.
	secfile = mktemp ("tmp$iterstat")
	sections (imginlist, option="section", > secfile)

# Loop through images
	img = ""
	sec = ""
	usec = ""
	imglist = infile
	seclist = secfile
	while (fscan (imglist, img) != EOF && fscan (seclist, sec) !=
	    EOF) {

	    # Compute the initial image statistics.
	    if (sec == "") {
		usec = statsec
	    } else {
		usec = sec
	    }

	    imstatistics (img // usec, fields="mean,stddev,npix,midpt,mode",
	        lower=lower, upper=upper, nclip=maxiter, lsigma=nsigrej,
		usigma=nsigrej, binwidth=0.1, format-, cache-) | scan (mn,
		sig, npx, med, mod)

	   # Optionally print the final results.
	   if (show) 
	       print (img, usec, ":  mn=", mn, " rms=", sig, " npix=", npx,
	           "  med=", med, " mode=", mod)

	   # Save the results in parameter values.
	   imean = mn
	   isigma = sig
	   imedian = med
	   imode = mod

	}

	# Delete the temporary root image and image section lists.
	delete (infile, go_ahead+, verify-, default_action+, allversions+,
	    subfiles+, > "dev$null")
	delete (secfile, go_ahead+, verify-, default_action+, allversions+,
	    subfiles+, > "dev$null")

	imglist = ""
	seclist = ""

end
