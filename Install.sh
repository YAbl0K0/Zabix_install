#!/usr/bin/env bash

hostname="$HOST_NAME"
server_ip="65.108.196.236"

if [[ -z "$hostname" ]]; then
    echo "Переменная окружения HOST_NAME не установлена"
    exit 1
fi

run_command() {
    echo "Выполнение команды: sudo $@"
    sudo "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Ошибка при выполнении команды: $1"
        exit $status
    fi
    echo "Команда успешно выполнена: $1"
    return $status
}

remove_old_zabbix(){
    echo "Начало удаления старого агента Zabbix"
    if systemctl list-units --full -all | grep -q "zabbix-agent"; then
        run_command systemctl stop zabbix-agent
        run_command apt remove -y zabbix-agent

        # Проверка на возможные проблемы с dpkg
        if [[ $? -ne 0 ]]; then
            echo "Ошибка при удалении пакета zabbix-agent. Попытка исправления..."
            run_command sudo dpkg --configure -a
            run_command apt remove -y zabbix-agent
        fi
    else
        echo "Служба zabbix-agent не найдена, пропуск остановки службы и удаления пакета."
    fi
    
    # Проверка наличия каталога /etc/zabbix/
    if [[ -d "/etc/zabbix/" ]]; then
        run_command rm -rf /etc/zabbix/
    fi
    
    echo "Старый агент Zabbix удалён"
}

install_zabbix(){
    echo "Начало установки агента Zabbix"
    if [[ ! -f "/etc/zabbix/zabbix_agentd.conf" ]]; then
        run_command apt remove --purge zabbix-agent -y
        run_command wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu20.04_all.deb
        run_command dpkg -i "zabbix-release_6.4-1+ubuntu20.04_all.deb"
        run_command apt-get update
        run_command apt-get install -y zabbix-agent
        run_command systemctl restart zabbix-agent
        run_command systemctl enable zabbix-agent
        run_command rm -f "zabbix-release_6.4-1+ubuntu20.04_all.deb"
    fi
    echo "Агент Zabbix установлен"
}

config_zabbix(){
    echo "Начало конфигурации агента Zabbix"
    run_command sed -i "s/Hostname=.*/Hostname=$hostname/g" /etc/zabbix/zabbix_agentd.conf
    run_command sed -i "s/Server=.*/Server=$server_ip/g" /etc/zabbix/zabbix_agentd.conf
    run_command sed -i "s/ServerActive=.*/ServerActive=$server_ip/g" /etc/zabbix/zabbix_agentd.conf
    run_command sed -i "s/# HostMetadata=/HostMetadata=autoreg.linux/" /etc/zabbix/zabbix_agentd.conf
    run_command systemctl restart zabbix-agent
    echo "Агент Zabbix сконфигурирован"
}

echo "Запуск скрипта"
remove_old_zabbix
install_zabbix
config_zabbix
echo "Скрипт успешно выполнен"
