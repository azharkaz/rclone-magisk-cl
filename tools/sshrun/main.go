package main

import (
	"fmt"
	"os"
	"strings"

	"golang.org/x/crypto/ssh"
)

// sshrun: выполняет произвольную команду на удалённом SSH-сервере.
// Используется как основа для авто-chmod +x на *.sh и файлах без расширения.
//
// Использование:
//   sshrun <host:port> <user> <password> <remote-command...>
//
// Пример (авто chmod +x на *.sh и файлах без расширения в /root, рекурсивно):
//   sshrun 172.29.159.62:22 root mypass \
//     find /root -type f '(' -name '*.sh' -o -not -name '*.*' ')' -exec chmod +x '{}' ';'

func main() {
	if len(os.Args) < 5 {
		fmt.Fprintln(os.Stderr, "usage: sshrun <host:port> <user> <password> <remote-command...>")
		os.Exit(2)
	}
	addr, user, pass := os.Args[1], os.Args[2], os.Args[3]
	cmd := strings.Join(os.Args[4:], " ")

	config := &ssh.ClientConfig{
		User:            user,
		Auth:            []ssh.AuthMethod{ssh.Password(pass)},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	}

	client, err := ssh.Dial("tcp", addr, config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ssh dial failed: %v\n", err)
		os.Exit(1)
	}
	defer client.Close()

	session, err := client.NewSession()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ssh session failed: %v\n", err)
		os.Exit(1)
	}
	defer session.Close()

	out, err := session.CombinedOutput(cmd)
	fmt.Print(string(out))
	if err != nil {
		fmt.Fprintf(os.Stderr, "remote command failed: %v\n", err)
		os.Exit(1)
	}
}
