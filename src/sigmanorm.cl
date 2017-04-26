# Sigmanorm renormalizes the input image by the square root of the exposure map
# to produce an image which should have uniform rms pixel-to-pixel noise across
# the entire area.

procedure sigmanorm (input, expmap, output)

# Sigmanorm call the minmax and imexpr tasks.

string	input		{prompt="The name of the input image"}
string	expmap		{prompt="The name of input exposure map image"}
string	output		{prompt="The output normalized image"}

begin
	real	maxexp
	string	img, expimg, oimg

# Get query parameter.

	img = input
	expimg = expmap
	oimg = output

# Calculate sqrt of exposure map and multiply into image with appropriate
# normalization.

	minmax (expimg, force-, update-, verbose-)
	maxexp = minmax.maxval

	imexpr ("a * sqrt (b / c)", oimg, img, expimg, maxexp, dims="auto",
	    intype="real", outtype="real", refim="auto", rangecheck=yes,
	    bwidth=0, btype="nearest", bpixval=0.0, exprdb="none",
	    verbose-)
end
