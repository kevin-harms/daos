//
// (C) Copyright 2018 Intel Corporation.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// GOVERNMENT LICENSE RIGHTS-OPEN SOURCE SOFTWARE
// The Government's rights to use, modify, reproduce, release, perform, display,
// or disclose this software are subject to the terms of the Apache License as
// provided in Contract No. 8F-30005.
// Any reproduction of computer software, computer software documentation, or
// portions thereof marked with this legend must also reproduce the markings.
//

package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"strings"
	"syscall"

	flags "github.com/jessevdk/go-flags"
	"google.golang.org/grpc"

	"github.com/daos-stack/daos/src/control/mgmt"
	mgmtpb "github.com/daos-stack/daos/src/control/mgmt/proto"
)

type cliOptions struct {
	Port       uint16  `short:"p" long:"port" description:"Port for the gRPC management interfect to listen on"`
	MountPath  string  `short:"s" long:"storage" description:"Storage path"`
	ConfigPath string  `short:"o" long:"config_path" description:"Server config file path"`
	Modules    *string `short:"m" long:"modules" description:"List of server modules to load"`
	Cores      uint16  `short:"c" long:"cores" default:"0" description:"number of cores to use (default all)"`
	Group      string  `short:"g" long:"group" description:"Server group name"`
	Attach     *string `short:"a" long:"attach_info" description:"Attach info patch (to support non-PMIx client, default /tmp)"`
	Map        *string `short:"y" long:"map" description:"[Temporary] System map file"`
	Rank       *uint   `short:"r" long:"rank" description:"[Temporary] Self rank"`
	SocketDir  string  `short:"d" long:"socket_dir" description:"Location for all daos_server & daos_io_server sockets"`
}

var opts cliOptions

func main() {
	runtime.GOMAXPROCS(1)

	// Parse commandline flags which override options loaded from config.
	_, err := flags.Parse(&opts)
	if err != nil {
		log.Fatalf("%s", err)
	}

	// Parse configuration file and load values, then backup active config.
	config := saveActiveConfig(loadConfigOpts(&opts))

	// Create a new server register our service and listen for connections.
	addr := fmt.Sprintf("0.0.0.0:%d", config.Port)
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatal("Unable to listen on management interface: ", err)
	}

	// TODO: This will need to be extended to take certificat information for
	// the TLS protected channel. Currently it is an "insecure" channel.
	var sOpts []grpc.ServerOption
	grpcServer := grpc.NewServer(sOpts...)

	mgmtControlServer := mgmt.NewControlServer()
	defer mgmtControlServer.Teardown()
	mgmtpb.RegisterMgmtControlServer(grpcServer, mgmtControlServer)
	go grpcServer.Serve(lis)
	defer grpcServer.GracefulStop()

	// Init socket and start drpc server to communicate with DAOS I/O servers.
	drpcSetup(config.SocketDir)

	// Create a channel to retrieve signals.
	sigchan := make(chan os.Signal, 2)
	signal.Notify(sigchan,
		syscall.SIGTERM,
		syscall.SIGINT,
		syscall.SIGQUIT,
		syscall.SIGKILL,
		syscall.SIGHUP)

	// Only start single server for now.
	ioIdx := 0
	ioArgs := config.Servers[ioIdx].CliOpts
	srv := exec.Command("daos_io_server", ioArgs...)
	srv.Stdout = os.Stdout
	srv.Stderr = os.Stderr
	srv.Env = os.Environ()

	// Init I/O server environment with values from config before starting.
	// Environment to be populated from config options but don't overwrite
	// existing os env vars.
	for _, env := range config.Servers[ioIdx].EnvVars {
		key := strings.Split(env, "=")[0]
		value := config.ext.getenv(key)
		if value == "" {
			// os env value doesn't exist so set
			srv.Env = append(srv.Env, env)
			continue
		}
		log.Printf("os env detected %s=%s, skipping...", key, value)
	}

	// I/O server should get a SIGTERM if this process dies.
	srv.SysProcAttr = &syscall.SysProcAttr{
		Pdeathsig: syscall.SIGTERM,
	}

	// Start the DAOS I/O server.
	err = srv.Start()
	if err != nil {
		log.Fatal("DAOS I/O server failed to start: ", err)
	}

	// Catch signals raised by I/O server.
	go func() {
		<-sigchan
		if err := srv.Process.Kill(); err != nil {
			log.Fatal("Failed to kill DAOS I/O server: ", err)
		}
	}()

	log.Printf(
		"DAOS server listening on %s%s", addr,
		checkReplica(lis, config.AccessPoints, srv))

	// Wait for I/O server to return.
	err = srv.Wait()
	if err != nil {
		log.Fatal("DAOS I/O server exited with error: ", err)
	}
}
