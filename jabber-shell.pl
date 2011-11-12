#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

use Net::XMPP;
use Net::Jabber;
use utf8;

# Список файлов конфигурации для перебора
my @configs = (
    $ENV{'HOME'}.'/.jabber-shell',   # Пользовательский файл конфигурации, должен быть в домашней директории: /home/user/.jabber-shell
    '/etc/jabber-shell.conf',        # Системный конфиг
);

# Хэш для хранения настроек
my %settings;

# Перебираем все файлы конфигурации
foreach my $config (@configs) {
    # Если файл существует и доступен для чтения
    if ( ( -e $config ) && ( -r $config) ) {
	# Читаем конфигурацию
	open(CONFIG, '<'.$config);
	local $/ = undef;
	my $config_data = <CONFIG>;
	close(CONFIG);
	%settings = eval($config_data);
	# Выходим из цикла
	last;
    }
}

# Если не удалось прочитать настройки - завершаем работу
if (!%settings) {
    die("Can't read settings!");
}

# Массив, в котором будут JID админов
my @admins = split(' ', $settings{'admins'});

# Определяем основные перменные
my $client   = new Net::Jabber::Client();
my $presense = Net::Jabber::Presence->new();

# Определяем обработчики событий
$client->SetCallBacks(
    'message' => \&on_message,
);

# Подключаемся к сети
# TODO: Обрабатывать ошибки подключения
$client->Connect(
    'hostname'        => $settings{'server'},
    'port'            => $settings{'port'},
);

my @connect = $client->AuthSend(
    'username'        => $settings{'username'},
    'password'        => $settings{'password'},
    'resource'        => $settings{'resource'},
);

# Устанавливаем статус
$presense->SetType("available");
$presense->SetStatus("");
$client->Send($presense);

# Функция обработки команд
sub process_command {
    my $command = shift;
    my $message = '';
    my $com = ' ';
    my $file = '';
    my $rubrick = '';
    my $null = '';
    
    # Если команда cd - пытаемся сменить директорию
    if	($command =~ s/^cd([ ]+)//) {
	if (chdir($command)) {
	    $message = 'Directory changed';
	}
	else {
	    $message = 'Directory NOT changed';
	}
    }
    # Если какая-то другая - выполняем её и возвращаем результат
    else {
#        open(COMMAND, $command." 2>&1 |");
#	local $/ = undef;
#	$message = <COMMAND>;
#        close(COMMAND);
	#$message = `$command 2>&1`;
	#$com = `echo "$command"|awk -F' ' '{print $$1}'`
	($com ) = split(' ', $command, 2);
	if ($com eq "новый") {
		($null, $file, $rubrick ) = split(' ', $command, 3);
		`echo "1\n$file\n$rubrick\ny" > INPUT;bash setup no <INPUT >OUTPUT_MSG`;
		$message = `cat OUTPUT_MSG|sed s/\e//g|grep ok`;
		#print "Строка 99, верно?\n$message";
	}
	elsif ($com eq "удалить")
	{
		($file) = split(' ', $command, 2);
		`echo "4\n$file" > INPUT;bash setup no <INPUT >OUTPUT_MSG`;
		$message = `cat OUTPUT_MSG|sed s/\e//g|grep ok`;
		}
	elsif ($com eq "ftp")
	{
		#($file) = split(' ', $command, 2);
		`./upload >OUTPUT_MSG`;
		$message = `cat OUTPUT_MSG`;
		}
	elsif ($com eq "выход")
	{
		exit 0;
	}
	elsif ($com eq "команды")
	{
		return "Команды:\n'новый' - добавить новый материал\n'присоеденить' - присоеденить файл\n'удалить' - удаляет элемент со страниц сайта. Файл на который ссылался элемент - удален не будет.\n'ftp' - обновить файлы по ftp\n'команды' - вывод списка команд\n'выход' - завершение работы";
	}
	else 
	{

		return "Команда не найдена. Для вывода списка команд напишите 'команды' без ковычек";
		
	}
	#$message = `$command 2>&1`;
    }
    #return $com;
    return $message;
}

# Функция обработки сообщений
sub on_message {
    my $mid = shift || return;
    my $msg = shift || return;
    
    # Команда, которую будем выполнять
    my $command = $msg->GetBody;
    # Получаем JID отправителя
    my $jid = new Net::XMPP::JID($msg->GetFrom)->GetJID("base");
    
    
    # Перебираем админов
    foreach my $admin (@admins) {
	# Если сообщение от одного из них
        if ($jid eq $admin) {
    	    # Обрабатываем сообщение и посылаем ответ
	    my $reply = Net::Jabber::Message->new();
	    
	    # ответ как "новое сообщение от пользователя"
	    #$reply->SetMessage(
		#'to'   => $msg->GetFrom,
		#'body' => process_command($command),
	    #);
	    
	    # ответ в том же окне
	    $reply->SetMessage(
		'to' => $msg->GetFrom,
		'body' => process_command($command),
		'type' => 'chat',
		);
		print "Sending message...\n";
	    $client->Send($reply);
	    print "Message outgoing...\n";
	}
    }
}

# Цикл обработки сообщений
while (defined($client->Process)) {
}
print "Vnezapnoe zavershenie...";
# На всякий случай закрываем соединение

$client->Disconnect();
exit 0;
