# Orient the image to within 45 degrees of north pointing up and east pointing 
# pointing left.

procedure orient (input, y2n_angle)

# Orient requires the imcopy and imtranpose tasks.

string input 	{prompt="The name of the image to reorient"}
real y2n_angle 	{0.,prompt="Angle in degrees from Y to N N thru E"}
bool rotation	{yes,prompt="Is N thru E counterclockwise ?"}
bool invert     {no,prompt="Inverse operation used for reorienting masks ?"}

begin
	real angle
	string image

# Get query parameters

	image = input
	angle = y2n_angle

# Set angle to a value from -45 to 315 degrees

	while (angle < -45.0) {
	    angle += 360. 
	}
	while (angle >= 315.0) {
	    angle -= 360.
	}
	
	if (angle < 45.0) {
	    if (rotation)
		return
	    else
		imcopy (image // "[-*,*]", image, verbose-)
	} else if (angle < 135.0) {
	    if (rotation) {
		if (invert) 
		    imtranspose (image // "[*,-*]", image, len_blk=1024)
		else 
		    imtranspose (image // "[-*,*]", image, len_blk=1024)
	    } else {
		imtranspose (image, image, len_blk=1024)
	    }
	} else if (angle < 225.0) {
	    if (rotation)
		imcopy (image // "[-*,-*]", image, verbose-)
	    else
		imcopy(image // "[*,-*]", image, verbose-)
	} else if (angle < 315.0) {
	    if (rotation) {
		if (invert)
		    imtranspose (image // "[-*,*]", image, len_blk=1024)
		else
		    imtranspose (image // "[*,-*]", image, len_blk=1024)
	    } else {
		imtranspose (image // "[-*,-*]", image, len_blk=1024)
	    }
	}

end
