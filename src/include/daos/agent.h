/*
 * (C) Copyright 2018 Intel Corporation.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * GOVERNMENT LICENSE RIGHTS-OPEN SOURCE SOFTWARE
 * The Government's rights to use, modify, reproduce, release, perform, display,
 * or disclose this software are subject to the terms of the Apache License as
 * provided in Contract No. 8F-30005.
 * Any reproduction of computer software, computer software documentation, or
 * portions thereof marked with this legend must also reproduce the markings.
 */

#ifndef __DAOS_AGENT_H__
#define __DAOS_AGENT_H__

/**
 * Default Unix Domain Socket path for the DAOS agent dRPC connection
 */
#define DEFAULT_DAOS_AGENT_DRPC_SOCK "/var/run/daos_agent/agent.sock"

/**
 * Environment variable for specifying an alternate dRPC socket path
 */
#define DAOS_AGENT_DRPC_SOCK_ENV "DAOS_AGENT_DRPC_SOCK"

/**
 * Definitions for DAOS agent dRPC modules and their methods.
 * These numeric designations are used in dRPC communications in the Drpc__Call
 * structure.
 */

/**
 *  Module: Security Agent
 *
 *  The agent module that deals with client security requests.
 */
#define DRPC_MODULE_SECURITY_AGENT				1

/**
 * Method: Request Credentials
 *
 * Requests authentication credentials for the current user.
 */
#define DRPC_METHOD_SECURITY_AGENT_REQUEST_CREDENTIALS		101

#endif /* __DAOS_AGENT_H__ */
