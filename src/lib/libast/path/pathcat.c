/***********************************************************************
 *                                                                      *
 *               This software is part of the ast package               *
 *          Copyright (c) 1985-2013 AT&T Intellectual Property          *
 *                      and is licensed under the                       *
 *                 Eclipse Public License, Version 1.0                  *
 *                    by AT&T Intellectual Property                     *
 *                                                                      *
 *                A copy of the License is available at                 *
 *          http://www.eclipse.org/org/documents/epl-v10.html           *
 *         (with md5 checksum b35adb5213ca9657e911e9befb180842)         *
 *                                                                      *
 *              Information and Software Systems Research               *
 *                            AT&T Research                             *
 *                           Florham Park NJ                            *
 *                                                                      *
 *               Glenn Fowler <glenn.s.fowler@gmail.com>                *
 *                    David Korn <dgkorn@gmail.com>                     *
 *                     Phong Vo <phongvo@gmail.com>                     *
 *                                                                      *
 ***********************************************************************/
/*
 * Glenn Fowler
 * AT&T Bell Laboratories
 *
 * single dir support for pathaccess()
 */
#include "config_ast.h"  // IWYU pragma: keep

#include <limits.h>  // for PATH_MAX
#include <stddef.h>

#include "ast.h"  // IWYU pragma: keep

#undef pathcat
char *pathcat(char *path, const char *dirs, int sep, const char *a, const char *b) {
    return pathcat_20100601(dirs, sep, a, b, path, PATH_MAX);
}

char *pathcat_20100601(const char *dirs, int sep, const char *a, const char *b, char *path,
                       size_t size) {
    char *s;
    char *e;

    s = path;
    e = path + size;
    while (*dirs && *dirs != sep) {
        if (s >= e) return 0;
        *s++ = *dirs++;
    }
    if (s != path) {
        if (s >= e) return 0;
        *s++ = '/';
    }
    if (a) {
        while ((*s = *a++)) {
            if (++s >= e) return 0;
        }
        if (b) {
            if (s >= e) return 0;
            *s++ = '/';
        }
    } else if (!b) {
        b = ".";
    }

    if (b) {
        do {
            if (s >= e) return 0;
        } while ((*s++ = *b++));
    }

    return *dirs ? (char *)++dirs : 0;
}
