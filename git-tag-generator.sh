#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

error_tag=false
work_prompt=''
hml_tag_version=''
prd_tag_version=''
confirm_tags=''
confirm_push=''
confirm_tag_description=''
remote_tags=''
tag_description=''
tag_version_regex="^v\.[0-9]+\.[0-9]+\.[0-9]+$"

hml_clients_prefix=(
    "CAB.projeto1.hml."
    "CAB.projeto2.hml."
    "CAB.projeto3.hml."
)

prd_clients_prefix=(
    "CAB.projeto1.prd."
    "CAB.projeto2.prd."
)

ready_tags=()

invalid_command() {
    echo -e "${RED}Comando inválido. Finalizando...."
    exit 1
}

exit_script () {
    echo -e "${NC}Finalizando...."
    exit 0
}

get_hml_tag_version_pattern() {
    echo -ne "${YELLOW}Informe a versão das tags de HML que serão geradas. Exemplo: ${NC}v0.0.0: "
    read -e  hml_tag_version

    if [[ ! "$hml_tag_version" =~ $tag_version_regex ]]; then
        invalid_command
    fi
}

get_prd_tag_version_pattern() {
    echo -ne "${YELLOW}Informe a versão das tags de PRD que serão geradas. Exemplo: ${NC}v0.0.0: "
    read -e  prd_tag_version

    if [[ ! "$prd_tag_version" =~ $tag_version_regex ]]; then
        invalid_command
    fi
}

generate_hml() {
    for prefix in "${hml_clients_prefix[@]}"; do
        new_tag="${prefix}${hml_tag_version}"
        ready_tags+=("$new_tag")
    done
}

generate_prd() {
    for prefix in "${prd_clients_prefix[@]}"; do
        new_tag="${prefix}${prd_tag_version}"
        ready_tags+=("$new_tag")
    done
}

generate_all() {
    generate_hml
    generate_prd
}

echo -e "${BLUE}"
echo "#######################################"
echo "#########  GIT TAG GENERATOR  #########"
echo "#######################################"
echo -e "${NC}"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Erro: não é um repositório Git.${NC}"
    exit 1
fi

echo -ne "${YELLOW}Digite H para homologação, P produção, T para todos ou S para sair: ${NC}"
read -e work_prompt

if [ "${#work_prompt}" -gt 1 ]; then
    invalid_command
fi

work_prompt_uppercase="${work_prompt^^}"

if [ "$work_prompt_uppercase" = "S" ]; then
    exit_script
elif [ "$work_prompt_uppercase" = "H" ]; then
    get_hml_tag_version_pattern
    generate_hml
elif [ "$work_prompt_uppercase" = "P" ]; then
    get_prd_tag_version_pattern
    generate_prd
elif [ "$work_prompt_uppercase" = "T" ]; then
    get_hml_tag_version_pattern
    get_prd_tag_version_pattern
    generate_all
else
    invalid_command
fi

echo -e "${BLUE}Verificando repositório local...${NC} \n"

for tag in "${ready_tags[@]}"; do
    if git tag -l "$tag" | grep -q "."; then
        echo -e "${RED} -> Tag $tag já existe localmente${NC}"
        error_tag=true
    else
        echo -e "${GREEN} -> Tag $tag${NC}"
    fi
done

echo -e "${BLUE}Verificando repositório remoto...${NC}\n"

remote_tags=$(git ls-remote --tags origin)

for tag in "${ready_tags[@]}"; do
    if echo "$remote_tags" | grep -q "refs/tags/${tag}$"; then
        echo -e "${RED} -> Tag $tag já existe remotamente${NC}"
        error_tag=true
    else
        echo -e "${GREEN} -> Tag $tag${NC}"
    fi
done

if [ "$error_tag" = "true" ]; then
    echo -e "${RED}Abortando...${NC}"
    exit 1;
else
    echo -e "${GREEN}Todas as tags estão disponíveis!${NC}"
fi

echo ""
echo -ne "${YELLOW}Deseja criar as tags? (s/n) ${NC}"
read -e confirm_tags

if [ "${#confirm_tags}" -gt 1 ]; then
    invalid_command
fi

confirm_tags_uppercase="${confirm_tags^^}"

if [ "${confirm_tags_uppercase}" = "S" ]; then
    echo -e "\n${BLUE}Iniciando a criação local...${NC}"

    echo -ne "${YELLOW}Deseja adicionar uma descrição nas tags? (s/n) ${NC}"
    read -e confirm_tag_description

    if [ "${#confirm_tag_description}" -gt 1 ]; then
        invalid_command
    fi

    confirm_tag_description_uppercase="${confirm_tag_description^^}"

    if [ "${confirm_tag_description_uppercase}" = "S" ]; then
        echo -ne "${YELLOW}Informe a descrição: ${NC}"
        read -e tag_description
    elif [ "${confirm_tag_description_uppercase}" = "N" ]; then
        tag_description="Release automatizado"

        echo -e "${BLUE}Usando descrição padrão: \"$tag_description\"${NC}"
    else
        invalid_command
    fi

    echo ""
    for tag in "${ready_tags[@]}"; do
        echo -e "Processando: $tag"

        if git tag -a "$tag" -m "$tag_description" 2>&1; then
            echo -e "${GREEN} -> Sucesso: Tag $tag criada localmente!${NC}"
        else
            echo -e "${RED} -> Falha crítica: Não foi possível criar a tag $tag. Abortando...${NC}"
            exit 1
        fi
    done

    echo -e "\n${GREEN}Todas as tags foram criadas localmente com sucesso!${NC}"

    echo -ne "${YELLOW}Deseja fazer o push dessas tags? (s/n)${NC} "
    read -e confirm_push

    if [ "${#confirm_push}" -gt 1 ]; then
        invalid_command
    fi

    confirm_push_uppercase="${confirm_push^^}"

    if [ "${confirm_push_uppercase}" = "S" ]; then
        if push_output=$(git push origin "${ready_tags[@]}" 2>&1); then
            echo -e "${GREEN} -> Sucesso!${NC}"
            echo "$push_output"
        else
            echo -e "${RED} -> Falha crítica:"
            echo "$push_output${NC}"
            exit 1
        fi
    elif [ "${confirm_push_uppercase}" = "N" ]; then
        exit_script
    else
        invalid_command
    fi

elif [ "${confirm_tags_uppercase}" = "N" ]; then
    exit_script
else
    invalid_command
fi
