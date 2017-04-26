string	root, temp, imtype
int	dx, dy, xs1, ys1, xs2, ys2
int	i1, i2, j1, j2
file	dat
real	bkg

artdata

root = "demo"
imtype = "." // envget ("imtype")
dx = 25
dy = 25
xs1 = 100
ys1 = 100
xs2 = 4 * xs1
ys2 = 4 * ys1
s2 = ""

for (k=1; k<=25; k+=1) {
    printf ("%s%02d\n", root, k) | scan (s2)
    if (!access (s2//imtype))
	break
    ;
}

if (k<=25) {
    printf ("Creating master field (please be patient) ...\n")

    dat = mktemp ("art")
    gallist (dat, 100, interactive=no, spatial="hubble", xmin=1., xmax=512.,
	ymin=1., ymax=512., xcenter=INDEF, ycenter=INDEF, core_radius=50.,
	base=0., sseed=2, luminosity="schecter", minmag=-7., maxmag=0.,
	mzero=15., power=0.6, alpha=-1.24, mstar=-21.41, lseed=2, egalmix=0.8,
	ar=0.7, eradius=20., sradius=1., absorption=1.2, z=0.05, sfile="",
	nssample=100, sorder=10, lfile="", nlsample=100, lorder=10,
	rbinsize=10., mbinsize=0.5, dbinsize=0.5, ebinsize=0.1, pbinsize=20.,
	graphics="stdgraph", cursor="")
    gallist (dat, 500, interactive=no, spatial="uniform", xmin=1.,
	xmax=512., ymin=1., ymax=512., xcenter=INDEF, ycenter=INDEF,
	core_radius=50., base=0., sseed=2, luminosity="powlaw", minmag=-7.,
	maxmag=0., mzero=15., power=0.6, alpha=-1.24, mstar=-21.41, lseed=2,
	egalmix=0.4, ar=0.7, eradius=20., sradius=1., absorption=1.2, z=0.05,
	sfile="", nssample=100, sorder=10, lfile="", nlsample=100, lorder=10,
	rbinsize=10., mbinsize=0.5, dbinsize=0.5, ebinsize=0.1, pbinsize=20.,
	graphics="stdgraph", cursor="")
    starlist (dat, 100, "", "", interactive=no, spatial="uniform", xmin=1.,
	xmax=512., ymin=1., ymax=512., xcenter=INDEF, ycenter=INDEF,
	core_radius=30., base=0., sseed=1, luminosity="powlaw", minmag=-7.,
	maxmag=0., mzero=-4., power=0.6, alpha=0.74, beta=0.04, delta=0.294,
	mstar=1.28, lseed=1, nssample=100, sorder=10, nlsample=100, lorder=10,
	rbinsize=10., mbinsize=0.5, graphics="stdgraph", cursor="")

    i1 = (512 - xs2 / 2) + 1
    j1 = (512 - ys2 / 2) + 1
    i2 = mod ((25 - 1) * dx, 5 * dx) + (512 - xs2 / 2) + 6
    j2 = mod (((25 - 1) / 5) * dy, 5 * dy) + (512 - ys2 / 2) + 6
    i2 = i2 + xs2 - 1
    j2 = j2 + ys2 - 1

    temp = mktemp ("art")
    artdata.dynrange = 1000.
    i1 = (512 - xs2 / 2)
    j1 = (512 - xs2 / 2)
    i2 = xs2 + 4 * dx + 6
    j2 = ys2 + 4 * dy + 6
    mkobjects (temp, output="", ncols=i2, nlines=j2,
	title="Example artificial galaxy cluster",
	header="artdata$stdheader.dat", background=0., objects=dat,
	xoffset=-i1, yoffset=-j1, star="moffat", radius=4.0, beta=2.5, ar=1.,
	pa=0., distance=0.5, exptime=1., magzero=6., gain=1., rdnoise=0.,
	poisson=no, seed=1, comments=no)
    artdata.dynrange = 100000.
    delete (dat, verify=no)

    s1 = root // "_truth"
    printf ("Creating truth image %s ...\n", s1)
    if (access (s1//imtype))
	imdelete (s1, verify=no)
    bkg = 5000.
    mknoise (temp, output=s1, background=bkg, gain=100.,
	rdnoise=10., poisson=yes, seed=1, cosrays="", ncosrays=0,
	energy=30000., radius=0.5, ar=1., pa=0., comments=no)

    printf ("Creating XDIMSUM bad pixel mask %s ...\n", root//".pl")
    if (access (root//".pl"))
	imdelete (root//".pl", verify=no)
    mkpattern (root//".pl", output="", pattern="constant", option="replace",
	v1=1., title="", pixtype="short", ndim=2, ncols=xs1, nlines=ys1,
	header="")
    mkpattern (root//".pl[20,*]", output="", pattern="constant",
	option="replace", v1=0., title="", pixtype="short", ndim=2,
	ncols=xs1, nlines=ys1, header="")
    mkpattern (root//".pl[30:32,10]", output="", pattern="constant",
	option="replace", v1=0., title="", pixtype="short", ndim=2,
	ncols=xs1, nlines=ys1, header="")
    mkpattern (root//".pl[10,30:32]", output="", pattern="constant",
	option="replace", v1=0., title="", pixtype="short", ndim=2,
	ncols=xs1, nlines=ys1, header="")

    printf ("Creating image list %s ...\n", root//".list")
    if (access (root//".list"))
	delete (root//".list", verify=no)

    printf ("Creating XDIMSUM shift list %s ...\n", root//".slist")
    if (access (root//".slist"))
	delete (root//".slist", verify=no)

    printf ("Creating imcombine offset file %s ...\n", root//".imc")
    if (access (root//".imc"))
	delete (root//".imc", verify=no)

    for (k=1; k<=25; k+=1) {
	i1 = mod ((k - 1) * dx, 5*dx) + 1 + mod (k-1, 7)
	j1 = mod (((k - 1) / 5) * dy, 5*dy) + 1 + mod (k-1, 7)
	i2 = i1 + xs2 - 1
	j2 = j1 + ys2 - 1

	printf ("%s[%d:%d,%d:%d]\n", temp, i1, i2, j1, j2) | scan (s1)
	printf ("%s%02d\n", root, k) | scan (s2)
	printf ("Creating %s ...\n", s2)
	if (access (s2//imtype))
	    imdelete (s2, verify=no)
	blkavg (s1, s2, 4, 4, option="average")
	wcsreset (s2, "physical", verbose-)
	imarith (s2, "*", root//".pl", s2)
	bkg = 4500. + k * 40
	mknoise (s2, output="", background=bkg, gain=2.,
	    rdnoise=10., poisson=yes, seed=k, cosrays="", ncosrays=3,
	    energy=20000., radius=0.1, ar=1., pa=0., comments=no)

	i = (i1 + 1) / 4
	j = (j1 + 1) / 4
	print (s2, >> root//".list")
	print (i, j, >> root//".imc")
	print (s2//".sub"//" ", -i, -j, 1, >> root//".slist")
    }

    imdelete (temp, verify=no)
} else
    ;
