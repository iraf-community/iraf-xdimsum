# FILEROOT parses a file name into root name and extension fields.

procedure fileroot(filename)

# The extension is assumed to be the portion of the file name which follows the
# last period in the input string supplied  by the user. The root is everything
# which preceeds that period.
#
# Included parameter validim to force a check to see if the  extension
# represents a valid IRAF image datatype, and if not, to negate the parsing.
# This would be a common usage;  often the user only wants to strip off the
# portion of the filename after the last period if that substring represents
# a valid IRAF image type such as .imh or .pl.  Without the validim parameter,
# if the file included another period somewhere in its name, then the portion
# of the filename after that period would be erroneously returned as an image
# extension.  At present, the routine only checks for a few datatypes;  this
# should be expanded in the future.
#
# Fileroot uses the strlen, substr, stridx, and envget CL builtins.



string	filename 	{prompt="File name"}
bool	validim		{no,prompt="Parse only if extension represents valid image datatype?"}
string	root		{"",prompt="Returned filename root"}
string	extension	{"",prompt="Returned filename extension"}
string	defextn		{"",prompt="Returned default filename extension"}

begin

# Declare local variables.

	string	imtype 	=	"imh",		
				"fits",
				"fit",
				"pl",
				"hhh",
				"qpoe",
				""
	string	fname, revname
	int 	ilen, ipos, ic, ii

# Get query parameter.

	fname = filename

# Reverse filename string character by character and store in revname.

	ilen = strlen (fname)
	revname = ""
	for (ic = ilen; ic >= 1; ic-=1) {
	    revname = revname // substr (fname, ic, ic)
	}

# Look for the first period in the reversed name.

	ipos = stridx (".", revname)

# If period exists, break filename into root and extension.  Otherwise,
# return null values for the extension, and the whole file name for the root.

	if (ipos != 0) {
	    root = substr (fname, 1, ilen-ipos)
	    extension = substr (fname, ilen - ipos + 2, ilen)
	} else {
	    root = fname
	    extension = ""
	}

# If validim = yes and extension != "", check to see if the parsed extension
# is a string indicating a valid image data type, e.g. "imh", "pl", etc.  
# If not, then undo the parsing, replacing the root with the complete input
# string 'filename' and setting the extension to null.

	if (validim && extension != "") {
	    ii = 1
	    while (imtype[ii] != "") {
		if (extension == imtype[ii]) break
		ii += 1
	    }
	    if (imtype[ii] == "") {
		root = fname
		extension = ""
	    }
	}

# Set default extension from "imtype" environment variable.
        
	defextn = "." // envget ("imtype")
	ipos = stridx (",", defextn)
	if (ipos > 0)
	    defextn = substr (defextn, 1, ipos-1)
end
