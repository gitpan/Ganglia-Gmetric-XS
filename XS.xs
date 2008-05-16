#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "ganglia.h"

#define XS_STATE(type, x) \
  INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x))

typedef struct ganglia_t {
  Ganglia_pool              context;
  Ganglia_gmetric           gmetric;
  Ganglia_udp_send_channels channel;
  Ganglia_gmond_config      gconfig;
} ganglia;

MODULE = Ganglia::Gmetric::XS    PACKAGE = Ganglia::Gmetric::XS

SV *
ganglia_initialize(class, config)
    SV   *class;
    char *config;
  PREINIT:
    ganglia *gang;
    SV *sv;
  CODE:
    if (SvROK(class))
      croak("Cannot call new() on a reference");
    Newxz(gang, 1, ganglia);
#ifdef DIAG
    PerlIO_printf(PerlIO_stderr(), "config:%s\n", config);
#endif

    gang->context = Ganglia_pool_create(NULL);
    if (! gang->context)
      croak("failed to Ganglia_pool_create");

    gang->gconfig = Ganglia_gmond_config_create(config, 0);
    if (! gang->gconfig)
      croak("failed to Ganglia_gmond_config_create");

    gang->channel = Ganglia_udp_send_channels_create(gang->context, gang->gconfig);
    if (! gang->channel)
      croak("failed to Ganglia_udp_send_channels_create");

    gang->gmetric = Ganglia_gmetric_create(gang->context);
    if (! gang->gmetric)
      croak("failed to Ganglia_gmetric_create");

    sv = newSViv(PTR2IV(gang));
    sv = newRV_noinc(sv);
    sv_bless(sv, gv_stashpv(SvPV_nolen(class), 1));
    SvREADONLY_on(sv);
    RETVAL = sv;
  OUTPUT:
    RETVAL

int
ganglia_send(self, name, value, type, units, slope, tmax, dmax)
    SV   *self;
    char *name;
    char *value;
    char *type;
    char *units;
    unsigned int slope;
    unsigned int tmax;
    unsigned int dmax;
  PREINIT:
    ganglia *gang;
  CODE:
    int   r;
    gang = XS_STATE(ganglia *, self);
#ifdef DIAG
    PerlIO_printf(PerlIO_stderr(), "send:%s=%s\n", name,value);
#endif
    r = Ganglia_gmetric_set(gang->gmetric, name, value, type, units, slope, tmax, dmax);
    switch(r) {
    case 1:
      croak("gmetric parameters invalid. exiting.\n");
    case 2:
      croak("one of your parameters has an invalid character '\"'. exiting.\n");
    case 3:
      croak("the type parameter \"%s\" is not a valid type. exiting.\n", type);
    case 4:
      croak("the value parameter \"%s\" does not represent a number. exiting.\n", value);
    }

    RETVAL = ! Ganglia_gmetric_send(gang->gmetric, gang->channel);
  OUTPUT:
    RETVAL

void
DESTROY(self)
    SV *self;
  PREINIT:
    ganglia *gang;
  CODE:
#ifdef DIAG
    PerlIO_printf(PerlIO_stderr(), "DESTROY: called\n" );
#endif
    gang = XS_STATE(ganglia *, self);
    if (gang == NULL) {
#ifdef DIAG
      PerlIO_printf(PerlIO_stderr(), "DESTROY: gang is null\n" );
#endif
      return;
    }

    if (gang->gmetric != NULL)
      Ganglia_gmetric_destroy(gang->gmetric);
    if (gang->context != NULL)
      Ganglia_pool_destroy(gang->context);
#ifdef DIAG
    PerlIO_printf(PerlIO_stderr(), "DESTROY: done\n" );
#endif
