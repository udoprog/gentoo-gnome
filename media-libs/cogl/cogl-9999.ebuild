# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="5"
CLUTTER_LA_PUNT="yes"

# Inherit gnome2 after clutter to download sources from gnome.org
inherit clutter gnome2 multilib virtualx
if [[ ${PV} = 9999 ]]; then
	inherit gnome2-live
fi

DESCRIPTION="A library for using 3D graphics hardware to draw pretty pictures"
HOMEPAGE="http://www.clutter-project.org/"

LICENSE="MIT BSD"
# XXX: git master has 99 as minor version.
SLOT="1.99/20" # subslot = .so version
# doc and profile disable for now due bugs #484750 and #483332
IUSE="examples gles2 gstreamer +introspection +opengl +pango test -wayland" # doc profile
if [[ ${PV} = 9999 ]]; then
	KEYWORDS=""
	IUSE="${IUSE} doc"
else
	KEYWORDS="~alpha ~amd64 ~arm ~ia64 ~mips ~ppc ~ppc64 ~sparc ~x86"
fi

COMMON_DEPEND="
	>=dev-libs/glib-2.32:2
	x11-libs/cairo:=
	>=x11-libs/gdk-pixbuf-2:2
	x11-libs/libdrm:=
	x11-libs/libX11
	>=x11-libs/libXcomposite-0.4
	x11-libs/libXdamage
	x11-libs/libXext
	>=x11-libs/libXfixes-3
	>=x11-libs/libXrandr-1.2
	virtual/opengl
	gles2? ( media-libs/mesa[gles2] )
	gstreamer? (
		media-libs/gstreamer:1.0
		media-libs/gst-plugins-base:1.0 )

	introspection? ( >=dev-libs/gobject-introspection-1.34.2 )
	pango? ( >=x11-libs/pango-1.20.0[introspection?] )
"
# before clutter-1.7, cogl was part of clutter
RDEPEND="${COMMON_DEPEND}
	!<media-libs/clutter-1.7"
DEPEND="${COMMON_DEPEND}
	>=dev-util/gtk-doc-am-1.13
	sys-devel/gettext
	virtual/pkgconfig
	test? (
		app-admin/eselect-opengl
		media-libs/mesa[classic] )
"

# Need classic mesa swrast for tests, llvmpipe causes a test failure

if [[ ${PV} = 9999 ]]; then
	DEPEND="${DEPEND}
		doc? (
			app-text/docbook-xml-dtd:4.1.2
			>=dev-util/gtk-doc-1.13 )"
fi

src_prepare() {
	# Do not build examples
	sed -e "s/^\(SUBDIRS +=.*\)examples\(.*\)$/\1\2/" \
		-i Makefile.am || die

	if ! use test ; then
		# For some reason the configure switch will not completely disable
		# tests being built
		sed -e "s/^\(SUBDIRS =.*\)test-fixtures\(.*\)$/\1\2/" \
    		-e "s/^\(SUBDIRS +=.*\)tests\(.*\)$/\1\2/" \
    		-e "s/^\(.*am__append.* \)tests\(.*\)$/\1\2/" \
			-i Makefile.am || die
	fi

	gnome2_src_prepare
}

src_configure() {
	# TODO: think about quartz, sdl
	# Prefer gl over gles2 if both are selected
	# Profiling needs uprof, which is not available in portage yet, bug #484750
	# FIXME: Doesn't provide prebuilt docs, but they can neither be rebuilt, bug #483332
	gnome2_src_configure \
		--disable-examples-install \
		--disable-maintainer-flags \
		--enable-cairo             \
		--enable-deprecated        \
		--enable-gdk-pixbuf        \
		--enable-glib              \
		--disable-gtk-doc          \
		$(use_enable opengl glx)   \
		$(use_enable opengl gl)    \
		$(use_enable gles2)        \
		$(use_enable gles2 cogl-gles2) \
		$(use_enable gles2 xlib-egl-platform) \
		$(usex gles2 --with-default-driver=$(usex opengl gl gles2)) \
		$(use_enable gstreamer cogl-gst)    \
		$(use_enable introspection) \
		$(use_enable pango cogl-pango) \
		$(use_enable test unit-tests) \
		$(use_enable wayland egl) \
		$(use_enable wayland wayland-egl-platform) \
		$(use_enable wayland wayland-egl-server) \
		$(use_enable wayland kms-egl-platform) \
		--disable-profile
#		$(use_enable doc gtk-doc)  \
#		$(use_enable profile)
}

src_test() {
	# Use swrast for tests, llvmpipe is incomplete and "test_sub_texture" fails
	# NOTE: recheck if this is needed after every mesa bump
	if [[ "$(eselect opengl show)" != "xorg-x11" ]]; then
		ewarn "Skipping tests because a binary OpenGL library is enabled. To"
		ewarn "run tests for ${PN}, you need to enable the Mesa library:"
		ewarn "# eselect opengl set xorg-x11"
		return
	fi
	LIBGL_DRIVERS_PATH="${EROOT}/usr/$(get_libdir)/mesa" Xemake check
}

src_install() {
	DOCS="NEWS README"
	EXAMPLES="examples/{*.c,*.jpg}"

	clutter_src_install

	# Remove silly examples-data directory
	rm -rvf "${ED}/usr/share/cogl/examples-data/" || die
}
