# Create file sublists from a master list.

procedure xlist (inlist, outlist, start, finish, exclude)

# If input list contains files 1 through N, xlist generates an  output
# list  containing files start to finish, and excluding file exclude. A prime
# example of the use of xlist would be for generating lists of images to be
# combined to make sky frames.

string	inlist	{prompt="Input file list in sequence"}
string 	outlist	{prompt="Output file list"}
int	start	{min=1,prompt="Number of first file to use in list"}
int	finish	{min=1,prompt="Number of last file to use in list"}
int	exclude	{min=0,prompt="Number of file to be excluded from list"}
string	suffix	{"",prompt="Suffix to append to file names in output list"}

string	*inlst

begin
	int	ilist, istart, ifinish, ixfile
	string 	fname, outlst

# Get query parameters.

	inlst	= inlist
	outlst	= outlist
	istart	= start
	ifinish	= finish
	ixfile	= exclude

# Now construct the list.

	ilist=1

	while (fscan (inlst, fname) != EOF) {
	    if (ilist > ifinish) break
	    if (ilist > (istart-1)) {
		if (ilist != ixfile) {
		    fileroot (fname, validim+)
		    if (fileroot.extension == "") {
		        print (fileroot.root // suffix, >> outlst)
		    } else {
		        print (fileroot.root // suffix // "." //
			    fileroot.extension, >> outlst)
		    }
		}
	    }
	    ilist += 1
	}

	inlst = ""
			    
end
