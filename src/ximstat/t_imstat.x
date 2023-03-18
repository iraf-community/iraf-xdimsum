# Copyright(c) 1986 Association of Universities for Research in Astronomy Inc.

include	<mach.h>
include	<imhdr.h>
include "mimstat.h"


# T_IMSTATISTICS -- Compute and print the statistics of images.

procedure t_imstatistics ()

real	lower, upper, binwidth, lsigma, usigma, low, up, hwidth, hmin, hmax
pointer	sp, fieldstr, fields, image, ist, v
pointer	im, buf, hgm
int	i, list, nclip, format, nfields, nbins, npix, cache, old_size

real	clgetr()
pointer	immap()
int	imtopenp(), btoi(), mst_fields(), imtgetim(), imgnlr(), mst_ihist()
int	clgeti()
bool	clgetb()
errchk	immap()

begin
	call smark (sp)
	call salloc (fieldstr, SZ_LINE, TY_CHAR)
	call salloc (fields, IS_NFIELDS, TY_INT)
	call salloc (image, SZ_FNAME, TY_CHAR)
	call salloc (v, IM_MAXDIM, TY_LONG)

	# Open the list of input images, the fields and the data value limits.
	list = imtopenp ("images")
	call clgstr ("fields", Memc[fieldstr], SZ_LINE)
	lower = clgetr ("lower")
	upper = clgetr ("upper")
	nclip = clgeti ("nclip")
	lsigma = clgetr ("lsigma")
	usigma = clgetr ("usigma")
	binwidth = clgetr ("binwidth")
	format = btoi (clgetb ("format"))
	cache = btoi (clgetb ("cache"))

	# Allocate space for statistics structure
	call mst_allocate (ist)

	# Get the selected fields.
	nfields = mst_fields (Memc[fieldstr], Memi[fields], IS_NFIELDS)
	if (nfields <= 0) {
	    call imtclose (list)
	    call sfree (sp)
	    return
	}

        # Set the processing switches
        call mst_switches (ist, Memi[fields], nfields, nclip)

        # Print header banner.
	if (format == YES)
            call mst_pheader (Memi[fields], nfields)

	# Loop through the input images.
	while (imtgetim (list, Memc[image], SZ_FNAME) != EOF) {

	    # Open the image.
	    iferr (im = immap (Memc[image], READ_ONLY, 0)) {
		call printf ("Error reading image %s ...\n")
		    call pargstr (Memc[image])
		next
	    }

	    if (cache == YES)
		call mst_cache1 (cache, im, old_size)
		
	    # Accumulate the central moment statistics.
	    low = lower
	    up = upper
	    do i = 0, nclip {

	        call mst_initialize (ist, low, up)
	        call amovkl (long(1), Meml[v], IM_MAXDIM)

	        if (MIS_SKURTOSIS(MIS_SW(ist)) == YES) {
	    	    while (imgnlr (im, buf, Meml[v]) != EOF)
		        call mst_accumulate4 (ist, Memr[buf],
			    int (IM_LEN(im, 1)), low, up,
			    MIS_SMINMAX(MIS_SW(ist)))
	    	} else if (MIS_SSKEW(MIS_SW(ist)) == YES) {
	    	    while (imgnlr (im, buf, Meml[v]) != EOF)
		        call mst_accumulate3 (ist, Memr[buf],
			    int (IM_LEN (im, 1)), low, up,
			    MIS_SMINMAX(MIS_SW(ist)))
	        } else if (MIS_SSTDDEV(MIS_SW(ist)) == YES ||
		    MIS_SMEDIAN(MIS_SW(ist)) == YES ||
		    MIS_SMODE(MIS_SW(ist)) == YES) {
	    	    while (imgnlr (im, buf, Meml[v]) != EOF)
		        call mst_accumulate2 (ist, Memr[buf],
			    int (IM_LEN(im,1)), low, up,
			    MIS_SMINMAX(MIS_SW(ist)))
	        } else if (MIS_SMEAN(MIS_SW(ist)) == YES) {
	    	    while (imgnlr (im, buf, Meml[v]) != EOF)
		        call mst_accumulate1 (ist, Memr[buf],
			    int (IM_LEN(im,1)), low, up,
			    MIS_SMINMAX(MIS_SW(ist)))
	        } else if (MIS_SNPIX(MIS_SW(ist)) == YES) {
	    	    while (imgnlr (im, buf, Meml[v]) != EOF)
		        call mst_accumulate0 (ist, Memr[buf],
			    int (IM_LEN(im,1)), low, up,
			    MIS_SMINMAX(MIS_SW(ist)))
	        } else if (MIS_SMINMAX(MIS_SW(ist)) == YES) {
	    	    while (imgnlr (im, buf, Meml[v]) != EOF)
		        call mst_accumulate0 (ist, Memr[buf],
			    int (IM_LEN(im,1)), low, up, YES)
	        }

	        # Compute the central moment statistics.
	        call mst_stats (ist)

                # Compute new limits and iterate.
                if (i < nclip) {
                    if (IS_INDEFR(lsigma))
                        low = -MAX_REAL
                    else if (lsigma > 0.0)
                        low = MIS_MEAN(ist) - lsigma * MIS_STDDEV(ist)
                    else
                        low = -MAX_REAL
                    if (IS_INDEFR(usigma))
                        up = MAX_REAL
                    else if (usigma > 0.0)
                        up = MIS_MEAN(ist) + usigma * MIS_STDDEV(ist)
                    else
                        up = MAX_REAL
                    if (i > 0) {
                        if (MIS_NPIX(ist) == npix)
                            break
                    }
                    npix = MIS_NPIX(ist)
                }

	    }

	    # Accumulate the histogram.
	    hgm = NULL
	    if ((MIS_SMEDIAN(MIS_SW(ist)) == YES || MIS_SMODE(MIS_SW(ist)) ==
	        YES) && mst_ihist (ist, binwidth, hgm, nbins, hwidth, hmin,
		hmax) == YES) {
		call aclri (Memi[hgm], nbins)
		call amovkl (long(1), Meml[v], IM_MAXDIM)
		while (imgnlr (im, buf, Meml[v]) != EOF)
		    call ahgmr (Memr[buf], int(IM_LEN(im,1)), Memi[hgm], nbins,
		        hmin, hmax)
		if (MIS_SMEDIAN(MIS_SW(ist)) == YES)
		    call mst_hmedian (ist, Memi[hgm], nbins, hwidth, hmin,
			hmax)
		if (MIS_SMODE(MIS_SW(ist)) == YES)
		    call mst_hmode (ist, Memi[hgm], nbins, hwidth, hmin, hmax)
	    }
	    if (hgm != NULL)
		call mfree (hgm, TY_INT)

	    # Print the statistics.
	    if (format == YES)
	        call mst_print (Memc[image], "", ist, Memi[fields], nfields)
	    else
	        call mst_fprint (Memc[image], "", ist, Memi[fields], nfields)
		
	    call imunmap (im)
	    if (cache == YES)
		call fixmem (old_size)
	}

	call mst_free (ist)
	call imtclose (list)
	call sfree (sp)
end
