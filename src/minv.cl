# Routine to invert mask of zeros and ones, i.e. to make 0 --> 1 and 1 --> 0.

procedure minv (infile, outfile)

string 	infile		{prompt = "Input mask image"}
string 	outfile		{prompt = "Output (inverted) mask image"}

begin

	string inf,outf

# Get query parameters:

	inf = infile
	fileroot (inf, validim+)
	inf = fileroot.root // ".pl"
	outf = outfile
	fileroot (outf, validim+)
	outf = fileroot.root // ".pl"

	if (inf != outf) {
	    #imcopy (inf, outf, ve-)
	    imexpr ("a == 1 ? 0 : 1", outf, inf, dims="auto", intype="auto",
		outtype="int", refim="auto", rangecheck=yes, bwidth=0,
		btype="nearest", bpixval=0.0, exprdb="none", verbose-)
	} else {
	    imreplace (outf, 2, imaginary=0.0, lower=0, upper=0, radius=0.0)
	    imarith (outf, "-", 1, outf, title="", divzero=0.0, hparams="",
		pixtype="", calctype="", verbose-, noact-)
	}

end
