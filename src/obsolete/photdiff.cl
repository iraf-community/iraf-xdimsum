procedure photdiff (photfile,output)

string	photfile	{prompt="Photometry data file from photcheck"}
string	output		{prompt="Output file"}
bool	display		{yes, prompt="Automatically display lightcurve (requires STSDAS)?"}
struct	*outdat

begin

	string	pfile,outp	# equal query parameters
	string	dimsumdir	# directory containing DIMSUM scripts
	string	igicommands
	string	filename
	real	ut, delta, err
	real	xmin, xmax, ymin, ymax
	real	xplotmin, xplotmax, yplotmin, yplotmax, ynumber

# If display==yes, check to see if stsdas.graphics.stplot is loaded, 
# and if not, load it.

	if (display) {
		if (!defpac("stsdas")) stsdas
		if (!defpac("stplot")) stplot
	}

# Get query parameters.

	pfile = photfile
	outp  = output

# Check for presence of the photcheck.diff.awk script in the DIMSUM source 
# code directory.  If that file is not present, return error message.

	dimsumdir = osfn("dimsumsrc$")
	if (!access(dimsumdir//"photcheck.diff.awk")) {
		print ("ERROR:   Cannot access ",dimsumdir//"photcheck.diff.awk")
		return
	}

# Use awk script to calculate photometric scalings between frames.

	awk ("-f",dimsumdir//"photcheck.diff.awk",pfile,>outp)

# If display==yes, call stsdas.graphics.stplot.igi to display light curve.

	if (display) {

# First, scan data values to determine plot limits.
# Skip first line.

		xmin = 1.E20
		xmax = -1.E20
		ymin = 1.E20
		ymax = -1.E20

		outdat = outp
		if (fscan(outdat,filename) == EOF) error (0,"No lines in file ",outdat)
		
		while (fscan(outdat,filename,ut,delta,err) != EOF) {
			xmin = min(xmin,ut)
			xmax = max(xmax,ut)
			ymin = min(ymin,delta-err)
			ymax = max(ymax,delta+err)
		}
		xplotmin = xmin - 0.1 * (xmax-xmin)
		xplotmax = xmax + 0.1 * (xmax-xmin)
		yplotmin = ymin - 0.2 * (ymax-ymin)
		yplotmax = ymax + 0.2 * (ymax-ymin)
		ynumber  = ymax + 0.1 * (ymax-ymin)
		
# Now open temporary file and create igi command macro.

		igicommands = mktemp("tmp$plotdiff")

		print ("limits ",xplotmin,xplotmax,yplotmin,yplotmax, >igicommands)
		print ("box", >>igicommands)
		print ("xlabel UT", >>igicommands)
		print ("ylabel \gDm", >>igicommands)
		print ("title Relative photometric scalings: ", outp, >>igicommands)
		print ("ltype 1", >>igicommands)
		print ("relocate ",xplotmin," 0.0 ", >>igicommands)
		print ("draw ",xplotmax," 0.0 ", >>igicommands)
		print ("ltype 0", >>igicommands)
		print ("data ",outp, >>igicommands)
#		print ("lines 1 1", >>igicommands)
#		print ("xcolumn 2", >>igicommands)
#		print ("ycolumn 3", >>igicommands)
#		print ("ptype 10 3", >>igicommands)
#		print ("points", >>igicommands)
		print ("lines 2 10000 ", >>igicommands)
		print ("xcolumn 2", >>igicommands)
		print ("ycolumn 3", >>igicommands)
		print ("ecol 4", >>igicommands)
		print ("ptype 4 0", >>igicommands)
		print ("points", >>igicommands)
		print ("error 2", >>igicommands)
		print ("error 4", >>igicommands)
		print ("yevaluate ",ynumber, >>igicommands)
		print ("angle 90", >>igicommands)
		print ("expand 0.5", >>igicommands)
		print ("number", >>igicommands)

# Execute igi with command macro, exit, then bring up graphics cursor to
# allow user to snapshot if desired.

		igi (initcmd="input "//igicommands//" ; end", >"dev$null")
		=gcur

	}

# Clean up.

	delete (igicommands,ver-)
	outdat = ""

end
