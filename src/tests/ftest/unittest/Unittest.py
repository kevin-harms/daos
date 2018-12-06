#!/usr/bin/python
'''
  (C) Copyright 2018 Intel Corporation.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  GOVERNMENT LICENSE RIGHTS-OPEN SOURCE SOFTWARE
  The Government's rights to use, modify, reproduce, release, perform, display,
  or disclose this software are subject to the terms of the Apache License as
  provided in Contract No. B609815.
  Any reproduction of computer software, computer software documentation, or
  portions thereof marked with this legend must also reproduce the markings.
'''
import sys


from apricot       import Test
from GeneralUtils  import get_file_path
from avocado.utils import process

class UnitTest(Test):
    """
    Execute Unit Tests
    :avocado: recursive
    """
    def tearDown(self):
        process.system("rm -f /mnt/daos/*")

    def test_smd_ut(self):
        """
        Test smd unittest.
        :avocado: tags=unittest,nvme,smd_ut
        """
        name = self.params.get("testname", '/run/UnitTest/smd_ut/*')
        bin_path = get_file_path(name)
        cmd = ("{0}".format(bin_path[0]))
        return_code = process.system(cmd)
        if return_code is not 0:
            self.fail("smd_ut unittest failed with return code={0}.\n"
                      .format(return_code))

    def test_vea_ut(self):
        """
        Test vea unittest.
        :avocado: tags=unittest,nvme,vea_ut
        """
        name = self.params.get("testname", '/run/UnitTest/vea_ut/*')
        bin_path = get_file_path(name)
        cmd = ("{0}".format(bin_path[0]))
        return_code = process.system(cmd)
        if return_code is not 0:
            self.fail("vea_ut unittest failed with return code={0}.\n"
                      .format(return_code))

    def test_pl_map(self):
        """
        Test pl_map unittest.
        :avocado: tags=unittest,pl_map
        """
        name = self.params.get("testname", '/run/UnitTest/pl_map/*')
        bin_path = get_file_path(name)
        cmd = ("{0}".format(bin_path[0]))
        return_code = process.system(cmd)
        if return_code is not 0:
            self.fail("pl_map unittest failed with return code={0}.\n"
                      .format(return_code))

    def test_eq_tests(self):
        """
        Test eq_tests unittest.
        :avocado: tags=unittest,eq_tests
        """
        name = self.params.get("testname", '/run/UnitTest/eq_tests/*')
        bin_path = get_file_path(name)
        cmd = ("{0}".format(bin_path[0]))
        return_code = process.system(cmd)
        if return_code is not 0:
            self.fail("eq_tests unittest failed with return code={0}.\n"
                      .format(return_code))

    def test_vos_tests(self):
        """
        Test eq_tests unittest.
        :avocado: tags=unittest,vos_tests
        """
        name = self.params.get("testname", '/run/UnitTest/vos_tests/*')
        bin_path = get_file_path(name)
        cmd = ("{0}".format(bin_path[0]))
        return_code = process.system(cmd)
        if return_code is not 0:
            self.fail("vos_tests unittest failed with return code={0}.\n"
                      .format(return_code))
