include <imhdr.h>

procedure t_maskinterp ()

char	image[SZ_FNAME]			# Image to correct
char	bpimage[SZ_FNAME]		# Bad pixel mask image
int	ibadvalue			# Value for bad pixels

int	i, ii, j, nc, nl, ilastgood, clgeti()
real	val, lastgood, delta
bool	gooddata
pointer	im, bp, imin, imout, bpin, immap(), imgl2r(), impl2r(), imgl2s()

begin
	call clgstr ("image", image, SZ_FNAME)
	call clgstr ("bpimage", bpimage, SZ_FNAME)
	ibadvalue = clgeti ("badvalue")

	im = immap (image, READ_WRITE, 0)
	bp = immap (bpimage, READ_ONLY, 0)

	nc = IM_LEN(im,1)
	nl = IM_LEN(im,2)

	if (IM_LEN(bp,1) != nc || IM_LEN(bp,2) != nl)
	    call error (1, "Image and mask files have mismatched dimensions.")

	do j = 1, nl {
	    imin = imgl2r (im, j)
	    imout = impl2r (im, j)
	    bpin = imgl2s (bp, j)

	    # Assume that we start off with good data.
	    gooddata = true
	    lastgood = 0.
	    ilastgood = 0

	    do i = 1, nc {
		val = Memr[imin+i-1]
		if (Mems[bpin+i-1] == ibadvalue) {	# Bad pixel...
		    if (gooddata)
			gooddata = false
		    if (i == nc && ilastgood != 0) {
			do ii = ilastgood+1, nc		# ...at end of row...
			    Memr[imin+ii-1] = lastgood
		    }
		} else {
		    if (!gooddata) {
			if (ilastgood == 0) {
			    do ii = 1, i-1		# ...at start of row...
				Memr[imin+ii-1] = val
			} else {			# ...interpolate...
			    delta = (val - lastgood) / (i - ilastgood)
			    do ii = ilastgood+1, i-1
				Memr[imin+ii-1] =
				    lastgood + (ii - ilastgood) * delta
			}
			gooddata = true
		    }
		    lastgood = val
		    ilastgood = i
		}
	    }
	    call amovr (Memr[imin], Memr[imout], nc)
	}

	call imunmap (bp)
	call imunmap (im)
end
