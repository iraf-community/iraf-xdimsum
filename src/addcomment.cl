# ADDCOMMENT appends 'COMMENT' cards to the image header. All existing 'COMMENT'
# cards are collated and moved to the end of the header, and the new card is
# added afterward.

procedure addcomment (inlist, comment)

# Addcomment uses the sections, hfix and delete tasks and the CL builtin task
# match.

string	inlist		{prompt="Image(s) to which to append comment card"}
string	comment		{prompt="Comment"}
bool	verify		{no, prompt="Verify header ?"}
bool	answer		{yes, prompt="Update this header ?", mode="q"}

struct	*inimglist

begin

	string 	tinlist, tcomment, imlist, headfile, img
	bool	setheader

# Get query parameters.

	tinlist = inlist
	tcomment = comment

	if (! verify) setheader = yes

# Create input image list.

	imlist = mktemp ("tmp$addc")
	sections (tinlist, option="fullname", > imlist)
	inimglist = imlist

# Loop over the input images.

	while (fscan (inimglist, img) != EOF) {

	    headfile = mktemp ("_headerjj")
	    hfix (img,
	        command="!grep -v 'COMMENT =' $fname > " // headfile, update-)
	    hfix (img, command="!grep 'COMMENT =' $fname >> " // headfile,
	        update-)
	    print("COMMENT = '", tcomment, "'", >> headfile)
	    if (verify) {
		print ("Comment cards currently read:")
		match ("COMMENT =", headfile, stop-, print+)
		if (answer) {
		    setheader = yes
		} else {
		    setheader = no
		    print ("Header will be left unchanged")
		}
	    }
	    if (setheader) { 
		hfix (img,
		    command="delete $fname ver- ; copy "//headfile//" $fname",
		    update+)
	    }
	    delete (headfile,ve-)
	}

# Cleanup

	inimglist = ""
	delete (imlist, ver-)

end
