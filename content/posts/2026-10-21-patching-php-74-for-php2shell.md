+++
title = "Patching PHP 7.4 for php2shell in a container"
date = 2026-10-21
description = "What I did to get the CVE-2026-109618 and CVE-2026-109619 fixes into a PHP 7.4 container."

[taxonomies]
tags = ["php","docker","containers","security"]
categories = ["software development"]
+++

It turns out that my [legacy PHP 7.4 applications on life support](@/posts/2025-08-01-the-pocket-guide-to-building-php-74-extensions-in-docker-containers-and-also-oci8.md) are still alive, kicking, and now even more vulnerable than before.

Earlier this morning, the PHP project put out a [security advisory](https://www.php.net/archive/2026.php#2026-10-21-5) for two critical remote code execution bugs:

- **CVE-2026-109618**, RCE via out-of-memory corruption ([GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w))
- **CVE-2026-109619**, RCE via stale global state ([GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp))

People are calling this **php2shell** and it seems to have leaked earlier than the intended disclosure. In short, anything serving web requests is exposed no matter how you run your PHP code, with a demonstrated exploit for Apache + mod_php.

PHP 7.4 went end of life in November 2022, and the official `php:7.4` Docker images stopped there: 7.4.33 on Debian 11 (bullseye). I am grateful that the PHP security team published minimal source backports for [7.4](https://github.com/php/php-src/tree/PHP-7.4-CVE-2026-109618-109619), [8.0](https://github.com/php/php-src/tree/PHP-8.0-CVE-2026-109618-109619) and [8.1](https://github.com/php/php-src/tree/PHP-8.1-CVE-2026-109618-109619).

For my old apps, the smallest change to address these vulnerabilities is to keep the official image and rebuild PHP inside it with the PHP team's [fix commit](https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2). The Containerfile below takes any of the `php:7.4` images (cli, fpm or apache) and:

1. Points apt at `archive.debian.org`.
2. Fetches the fix commit from php-src.
3. Rebuilds PHP from the image's own 7.4.33 source, using the image's original configure flags (`php-config --configure-options`).
4. Copies the new binaries and the patched source back over the original image.
5. Pulls in the last security updates Debian 11 got. The official images stopped at 11.5.

Step 4 ships the patched source because `docker-php-ext-install` builds extensions from it.

Also, because Debian 11's security support has ended, its security packages on `deb.debian.org` now return 404. Anything still built on the official `php:7.4` image needs to use `archive.debian.org` before it can `apt-get install` anything.

```dockerfile
# Change or override this for another flavor
ARG PHP_IMAGE=php:7.4-cli 

FROM ${PHP_IMAGE} AS build

# "Avoid state corruption via bailout" on php-src's PHP-7.4-CVE-2026-109618-109619
ARG PHP_FIX_COMMIT=712e60f9edfd03f0960fc4fc3c2c375f42b90aa2

RUN set -eux; \
	{ \
		echo 'deb http://archive.debian.org/debian bullseye main'; \
		echo 'deb http://archive.debian.org/debian bullseye-updates main'; \
		echo 'deb http://archive.debian.org/debian-security bullseye-security main'; \
	} > /etc/apt/sources.list; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		$PHPIZE_DEPS git patch \
		libargon2-dev libcurl4-openssl-dev libonig-dev libreadline-dev libsodium-dev \
		libsqlite3-dev libssl-dev libxml2-dev zlib1g-dev \
	; \
	case "$(php-config --configure-options)" in \
		*--with-apxs2*) apt-get install -y --no-install-recommends apache2-dev ;; \
	esac

RUN set -eux; \
	git init -q /usr/src/php-fix; \
	cd /usr/src/php-fix; \
	git remote add origin https://github.com/php/php-src.git; \
	git fetch -q --depth 2 --filter=blob:none origin "$PHP_FIX_COMMIT"; \
	git diff "$PHP_FIX_COMMIT^" "$PHP_FIX_COMMIT" > /usr/src/php-fix.patch

RUN set -eux; \
	export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"; \
	configureOptions="$(php-config --configure-options)"; \
	docker-php-source extract; \
	cd /usr/src/php; \
	patch -p1 --forward --no-backup-if-mismatch < /usr/src/php-fix.patch; \
	\
# Ship the patched source too, so docker-php-ext-install builds against it.
	mkdir -p /out/usr/src; \
	tar -cJf /out/usr/src/php.tar.xz -C /usr/src --exclude=.docker-delete-me \
		--transform 's,^php,php-7.4.33,' php; \
	\
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	[ -e /usr/include/curl ] || [ -e /usr/local/include/curl ] \
		|| ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	./configure $configureOptions; \
	make -j "$(nproc)"; \
# apxs (apache variant) wants a config dir; the image's own config is kept.
	mkdir -p /out/etc/apache2/mods-available; \
	make INSTALL_ROOT=/out install-sapi install-binaries install-build \
		install-headers install-programs install-modules; \
	rm -rf /out/etc; \
	find /out -type f -perm '/0111' -exec strip --strip-all '{}' + || :

FROM ${PHP_IMAGE}

RUN set -eux; \
	{ \
		echo 'deb http://archive.debian.org/debian bullseye main'; \
		echo 'deb http://archive.debian.org/debian bullseye-updates main'; \
		echo 'deb http://archive.debian.org/debian-security bullseye-security main'; \
	} > /etc/apt/sources.list; \
	apt-get update; \
	apt-get upgrade -y; \
	rm -rf /var/lib/apt/lists/*

COPY --from=build /out/ /

RUN set -eux; \
	rm -f /usr/src/php.tar.xz.asc; \
	php --version
```

This also changes one thing about how apps behave. **Session upload progress is now always off**, no matter what `session.upload_progress.enabled` says. That's part of the PHP team's mitigation. Uploads work fine, but if you poll `$_SESSION` for a progress bar, you'll get nothing.

This only fixes the current CVEs on a base that no longer gets security updates. For modern systems, I recommend checking out [Ondřej Surý's packages](https://deb.sury.org/). Sury has been backporting security fixes to 7.4 long after end of life. His `php7.4 7.4.33-31` package went out today with the php2shell fix, on top of years of other backports.

## Sources

- [PHP security advisory, 2026-10-21](https://www.php.net/archive/2026.php#2026-10-21-5)
- [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) (CVE-2026-109618) and [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) (CVE-2026-109619)
- [php-src PHP 7.4 backport branch](https://github.com/php/php-src/tree/PHP-7.4-CVE-2026-109618-109619)
- [Sury's PHP repository README](https://packages.sury.org/php/README.txt) and [release-day notes](https://codeberg.org/oerdnj/deb.sury.org/issues/145)
- [Tenable: php2shell FAQ](https://www.tenable.com/blog/php2shell-cve-2026-109618-cve-2026-109619-frequently-asked-questions-about-critical-php-remote)
- [Huntress: php2shell](https://www.huntress.com/blog/php2shell-leaked-critical-php-vulnerabilities)
