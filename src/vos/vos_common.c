#include <daos/daos_common.h>
#include "vos_internal.h"


int
vos_create_hhash(void)
{
	static pthread_mutex_t	create_mutex = PTHREAD_MUTEX_INITIALIZER;
	static int		hhash_is_create = 0;
	int			ret = 0;

	if (!hhash_is_create) {
		pthread_mutex_lock(&create_mutex);
		if (!hhash_is_create) {
			ret = daos_hhash_create(DAOS_HHASH_BITS,
						&daos_vos_hhash);
			if (ret != 0) {
				D_ERROR("VOS hhash creation error\n");
				pthread_mutex_unlock(&create_mutex);
				return ret;
			}
			hhash_is_create = 1;
		}
		pthread_mutex_unlock(&create_mutex);
	}
	return ret;
}

struct vos_pool*
vos_pool_lookup_handle(daos_handle_t poh)
{
	struct vos_pool		*vpool = NULL;
	struct daos_hlink	*hlink = NULL;

	hlink = daos_hhash_link_lookup(daos_vos_hhash, poh.cookie);
	if (NULL == hlink)
		D_ERROR("VOS pool handle lookup error\n");
	else
		vpool = container_of(hlink, struct vos_pool,
				     vpool_hlink);
	return vpool;
}

