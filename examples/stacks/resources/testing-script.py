#!/usr/bin/env python3
#
# hello-maas - Simple release script.
#
# Copyright (C) 2016-2024 Canonical
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# --- Start MAAS 1.0 script metadata ---
# name: hello-test
# title: Simple script
# description: Simple script
# script_type: testing
# packages:
#   apt:
#     - moreutils
# --- End MAAS 1.0 script metadata --

import socket

host = '10.20.0.1'
port = 3333
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((host, port))
s.sendall(b'Hello, test\n')
s.close()

