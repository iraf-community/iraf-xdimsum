# T_AVSHIFT -- Compute the average shifts between the reference coordinates
# in pixels (columns 1 and 2) and the input coordinates in pixels (columns
# 3 and 4).

procedure t_avshift()

double	sumdx, sumdy
real	x1, y1, x2, y2, dx, dy
pointer	sp, input
int	fd, npts
int	open(), fscan(), nscan()

begin
	call smark (sp)
	call salloc (input, SZ_FNAME, TY_CHAR)

	call clgstr ("input", Memc[input], SZ_FNAME)
	fd = open (Memc[input], READ_ONLY, TEXT_FILE)

	# Loop over the coordinates.
	npts = 0
	sumdx = 0.0d0
	sumdy = 0.0d0
	while (fscan (fd) != EOF) {
	    call gargr (x1)
	    call gargr (y1)
	    call gargr (x2)
	    call gargr (y2)
	    if (nscan() < 4)
		next
	    npts = npts + 1
	    sumdx = sumdx + (x1 - x2)
	    sumdy = sumdy + (y1 - y2)
	}

	# Compute the average shift.
	if (npts == 0) {
	    call printf ("INDEF INDEF  0\n")
	} else if (npts == 1) {
	    dx = sumdx
	    dy = sumdy
	    call printf ("%g %g  1\n")
		call pargr (dx)
		call pargr (dy)
	} else {
	    dx = sumdx / npts
	    dy = sumdy / npts
	    call printf ("%g  %g  %d\n")
		call pargr (dx)
		call pargr (dy)
		call pargi (npts)
	}

	call close (fd)

	call sfree (sp)
end
