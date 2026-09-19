package main

import (
	"fmt"
	"os"

	"golang.org/x/crypto/ssh"
)

// sshchmod: минимальная утилита прямого chmod на удалённом SFTP/SSH-сервере,
// в обход VFS-слоя rclone (который принимает Setattr, но не применяет его).
//
// Использование:
//   sshchmod <host:port> <user> <password> <mode-octal> <remote-path>
// Пример:
//   sshchmod 172.29.159.62:22 root mypass 750 /root/docs/report.pdf

func main() {
	if len(os.Args) != 6 {
		fmt.Fprintln(os.Stderr, "usage: sshchmod <host:port> <user> <password> <mode-octal> <remote-path>")
		os.Exit(2)
	}
	addr, user, pass, mode, path := os.Args[1], os.Args[2], os.Args[3], os.Args[4], os.Args[5]

	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.Password(pass),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // сервер уже в доверенном локальном контуре пользователя
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

	// экранируем путь простым способом через одинарные кавычки
	cmd := fmt.Sprintf("chmod %s '%s'", mode, shellEscape(path))
	out, err := session.CombinedOutput(cmd)
	if err != nil {
		fmt.Fprintf(os.Stderr, "remote chmod failed: %v\noutput: %s\n", err, string(out))
		os.Exit(1)
	}
	fmt.Println("OK")
}

func shellEscape(s string) string {
	// заменяем одинарные кавычки на безопасную последовательность
	out := ""
	for _, r := range s {
		if r == '\'' {
			out += `'\''`
		} else {
			out += string(r)
		}
	}
	return out
}
