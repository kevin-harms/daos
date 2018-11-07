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

from apricot       import TestWithServers, skipForTicket
from avocado.utils import process

class DaosCoreTest(TestWithServers):
    """
    Runs the daos_test subtests with multiple servers.

    :avocado: recursive
    """
    def setUp(self):
        self.subtest_name = self.params.get("test_name", '/run/daos_tests/Tests/*')

        if self.subtest_name == "rebuild tests":
            # TODO: should actually check the servers for memory in the
            #       real world
            #       although in the real world, we wouldn't get servers
            #       that didn't have enough memory
            self.cancel('Not enough memory on test servers to run rebuild tests')
        if self.subtest_name == "IO test":
            self.cancelForTicket('DAOS-1584')

        super(DaosCoreTest, self).setUp()

    def test_subtest(self):
        """
        Test ID: DAOS-1568

        Test Description: Run daos_test with a subtest argument

        Use Cases: core tests for daos_test

        :avocado: tags=all,daos_test,multiserver,vm
        """

        subtest = self.params.get("daos_test", '/run/daos_tests/Tests/*')
        num_clients = self.params.get("num_clients",
                                      '/run/daos_tests/num_clients/*')
        num_replicas = self.params.get("num_replicas",
                                       '/run/daos_tests/num_replicas/*')

        cmd = "{0} -n {1} {2} -s {3} -{4}".format(self.orterun, num_clients,
                                                  self.daos_test, num_replicas,
                                                  subtest)

        env = {}
        env['CMOCKA_XML_FILE'] = self.tmp + "/%g_results.xml"
        env['CMOCKA_MESSAGE_OUTPUT'] = "xml"

        try:
            process.run(cmd, env=env)
        except process.CmdError as result:
            if result.result.exit_status is not 0:
                # fake a JUnit failure output
                with open(self.tmp + "/" + self.subtest_name +
                          "_results.xml", "w") as results_xml:
                    results_xml.write('''<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="{0}" errors="1" failures="0" skipped="0" tests="1" time="0.0">
  <testcase name="ALL" time="0.0" >
    <error message="Test failed to start up"/>
    <system-out>
<![CDATA[{1}]]>
    </system-out>
    <system-err>
<![CDATA[{2}]]>
    </system-err>
  </testcase>
</testsuite>'''.format(self.subtest_name, result.result.stdout,
                       result.result.stderr))
                self.fail("{0} failed with return code={1}.\n"
                          .format(cmd, result.result.exit_status))
