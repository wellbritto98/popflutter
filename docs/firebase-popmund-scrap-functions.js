const functions = require('firebase-functions');
const puppeteer = require('puppeteer');
const chromium = require('chromium');
const {
    error
} = require('firebase-functions/logger');
const { timeout } = require('puppeteer');
const cors = require('cors')({
    origin: true
});

const runtimeOpts = {
    timeoutSeconds: 120,
    memory: '1GB'
};

//foco controller
exports.ensaiarCena = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await ensaiarCena(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Foco alterado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao ensaiar cena.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao ensaiar cena.'
            });
        }
    });
});

exports.comporMusica = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await comporMusica(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Foco alterado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao compor música.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao compor música.'
            });
        }
    });
});

exports.falarComImprensa = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await falarComImprensa(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Foco alterado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao falar com imprensa.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao falar com imprensa.'
            });
        }
    });
});


//lazer controller
exports.malhar = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await malhar(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Lazer alterado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao malhar.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao malhar.'
            });
        }
    });
});

exports.passear = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await passear(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Lazer alterado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao passear.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao passear.'
            });
        }
    });
});

exports.descansar = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await descansar(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Lazer alterado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao descansar.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao descansar.'
            });
        }
    });
});

//band controller

exports.pagarEquipe = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await pagarEquipe(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Equipe paga com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao pagar equipe.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao pagar equipe.'
            });
        }
    });
});

//items controller

exports.usarItem = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;
        const nomeItem = req.query.nomeItem; // O nome do item é passado como um parâmetro de consulta

        if (!login || !senha || !nomeChar || !nomeItem) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await usarItem(page, urlDomain, nomeItem); // Chama a função genérica
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: `${nomeItem} usado com sucesso`
            }) : res.status(400).json({
                message: `Erro ao usar ${nomeItem}.`
            });

        } catch (error) {
            res.status(400).json({
                message: `Erro ao usar ${nomeItem}.`
            });
        }
    });
});

exports.cadastrarChars = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;

        if (!login || !senha) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const result = await cadastrarChars(login, senha);

            // Adicionando log para verificar o retorno da função cadastrarChars
            console.log("Resultado de cadastrarChars:", result);

            result ? res.json(result) : res.status(400).json({
                message: 'Erro ao encontrar chars.'
            });

        } catch (error) {
            console.error("Erro no catch:", error);
            res.status(400).json({
                message: 'Erro ao encontrar chars.'
            });
        }
    });
});


exports.criarMusica = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;
        const musicName = req.query.musicName
        const gender = req.query.gender
        const melody = req.query.melody
        const tempo = req.query.tempo

        if (!login || !senha || !nomeChar || !musicName || !gender || !melody || !tempo) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await criarMusica(page, urlDomain, musicName, gender, melody, tempo);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Música criada com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao criar música.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao criar música.'
            });
        }
    });
});

exports.finalizarMusica = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await finalizarMusica(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Música finalizada com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao finalizar música.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao finalizar música.'
            });
        }
    });
}
);

exports.irAcademia = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await irAcademia(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Academia acessada com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao acessar academia.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao acessar academia.'
            });
        }
    });
}
);

exports.irJantar = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await irJantar(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Jantar acessado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao acessar jantar.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao acessar jantar.'
            });
        }
    });
}
);

exports.verificarSaude = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await verificarSaude(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'sucesso'
            }) : res.status(400).json({
                message: 'Erro'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro '
            });
        }
    });
}
);

exports.verificarMuvasica = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;
        const musicName = req.query.musicName;
        const gender = req.query.gender;
        const melody = req.query.melody;
        const tempo = req.query.tempo;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await verificarMusica(page, urlDomain, musicName, gender, melody, tempo);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'sucesso'
            }) : res.status(400).json({
                message: 'Erro'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro '
            });
        }
    });
}
);

exports.usarPersonalTrainer = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await usarPersonalTrainer(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Personal Trainer usado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao usar Personal Trainer.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao usar Personal Trainer.'
            });
        }
    });
});

exports.verificarAmbicao = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await verificarAmbição(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Ambição verificada com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao verificar ambição.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao verificar ambição.'
            });
        }
    });
});

exports.repararEquipamentos = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await repararEquipamentos(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Equipamentos reparados com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao reparar equipamentos.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao reparar equipamentos.'
            });
        }
    });
});

exports.comprarUpExtra = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await comprarUpExtra(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Up Extra comprado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao comprar Up Extra.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao comprar Up Extra.'
            });
        }
    });
});

exports.irHotel = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;

        if (!login || !senha || !nomeChar) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await irHotel(page, urlDomain);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Hotel acessado com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao acessar hotel.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao acessar hotel.'
            });
        }
    });
});

exports.usarFlanela = functions.runWith(runtimeOpts).https.onRequest(async (req, res) => {
    cors(req, res, async () => {
        const login = req.query.login;
        const senha = req.query.senha;
        const nomeChar = req.query.nomeChar;
        const instrumento = req.query.instrumento;

        if (!login || !senha || !nomeChar || !instrumento) {
            res.status(400).json({
                message: 'Dados inválidos.'
            });
            return;
        }

        try {
            const {
                browser,
                page,
                urlDomain
            } = await initialSetup(login, senha, nomeChar);
            const result = await usarFlanela(page, urlDomain, instrumento);
            await browser.close();
            result == 'Sucesso' ? res.json({
                message: 'Flanela usada com sucesso'
            }) : res.status(400).json({
                message: 'Erro ao usar Flanela.'
            });

        } catch (error) {
            res.status(400).json({
                message: 'Erro ao usar Flanela.'
            });
        }
    });
}
);

/////////////////////////////////////////////////////////////////////
// Funções de apoio
/////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////

async function usarFlanela(page, urlDomain, instrumento) {
    // Acesse a página desejada
    await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Character/Items/`);

    // Executa dentro do contexto da página para buscar o link da Flanela
    let flanelaLink = await page.evaluate(() => {
        // Encontra a TR que contém o texto do item
        const row = Array.from(document.querySelectorAll('tr')).find(tr =>
            tr.innerText.trim().includes('Flanela') || tr.innerText.trim().includes('Rag')
        );

        if (row) {
            // Busca o elemento <a> dentro da linha encontrada
            const linkElement = row.querySelector('a');
            if (linkElement) {
                return linkElement.href; // Retorna o href completo
            }
        }
        return null; // Retorna null caso não encontre
    });

    if (flanelaLink) {
        console.log(`Link da Flanela: ${flanelaLink}`);
        await goToPage(page, `${flanelaLink}`);
        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_ddlItemSpecialUse', {
            timeout: 2000
        });
        // Seleciona o instrumento pelo nome
        await page.evaluate((instrumentoNome) => {
            const select = document.querySelector('#ctl00_cphLeftColumn_ctl00_ddlItemSpecialUse');
            if (select) {
                const optionToSelect = Array.from(select.options).find(option =>
                    option.textContent.trim().startsWith(instrumentoNome) // Usando startsWith
                );
                if (optionToSelect) {
                    select.value = optionToSelect.value; // Define o value correspondente
                }
            }
        }, instrumento);  
        await page.click('#ctl00_cphLeftColumn_ctl00_btnItemSpecialUse');
        
        await page.waitForSelector('.notification-success', {
            timeout: 2000
        });
        return 'Sucesso';
    } else {
        console.log('Flanela não encontrada na página.');
    }
}



async function comprarUpExtra(page, urlDomain) {
    await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Character/CreditProduct/22`);
    await page.waitForSelector('#ctl00_cphLeftColumn_ctl01_btnBuyCP', {
        timeout: 2000
    });

    await page.click('#ctl00_cphLeftColumn_ctl01_btnBuyCP');
    await page.waitForSelector('.ui-dialog-buttonset', {
        timeout: 2000
    });

    await page.evaluate(() => {
        const buttonSet = document.querySelector('.ui-dialog-buttonset');
        const confirmButton = buttonSet.querySelector('button:first-child'); // Seleciona o primeiro botão
        if (confirmButton) {
            confirmButton.click();
        }
    });

    await page.waitForSelector('.notification-success', {
        timeout: 2000
    });

    

    return 'Sucesso'; 
}

async function repararEquipamentos(page, urlDomain) {
    await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Artist/Equipment/`);
    await page.waitForSelector('#ctl00_cphLeftColumn_ctl01_btnServiceEquipment', {
        timeout: 2000
    });

    // Clicar no botão para abrir o diálogo de confirmação
    await page.click('#ctl00_cphLeftColumn_ctl01_btnServiceEquipment');

    // Aguardar o diálogo aparecer
    await page.waitForSelector('.ui-dialog-buttonset', {
        timeout: 2000
    });

    // Clicar no primeiro botão "Sim" dentro do diálogo
    await page.evaluate(() => {
        const buttonSet = document.querySelector('.ui-dialog-buttonset');
        const confirmButton = buttonSet.querySelector('button:first-child'); // Seleciona o primeiro botão
        if (confirmButton) {
            confirmButton.click();
        }
    });

    return 'Sucesso';
}


async function verificarAmbição(page, urlDomain) {
    try {
        // Navegar para a página do artista
        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Artist`);
        await page.waitForSelector('#ctl00_cphLeftColumn_ctl01_divLatestShows', {
            timeout: 2000
        });

        let irComTudo = false;

        // Obter o HTML das duas primeiras linhas
        const cidades = await page.evaluate(() => {
            // Seleciona os elementos das cidades nas duas primeiras linhas
            const rows = Array.from(document.querySelectorAll('#ctl00_cphLeftColumn_ctl01_divLatestShows table.data tr'));
            if (rows.length < 2) return []; // Se não houver pelo menos duas linhas, retorna vazio
            return rows.slice(0, 2).map(row => {
                const cityElement = row.querySelector('td:nth-child(2) a');
                return cityElement ? cityElement.textContent.trim() : null;
            });
        });

        // Verificar se as duas primeiras cidades são iguais
        if (cidades.length === 2 && cidades[0] === cidades[1]) {
            irComTudo = true;
        }

        console.log('irComTudo:', irComTudo);

        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Artist/Preferences/`);
        await page.waitForSelector('#ctl00_cphLeftColumn_ctl02_ddlPreferenceOptions', {
            timeout: 2000
        });


        if (irComTudo) {
            await page.select('#ctl00_cphLeftColumn_ctl02_ddlPreferenceOptions', '15');
            setTimeout(() => {
                page.click('#ctl00_cphLeftColumn_ctl02_btnSetPreference');
            }, 1000);


            await page.waitForSelector('.notification-success', {
                timeout: 5000
            });

        }
        else {
            await page.select('#ctl00_cphLeftColumn_ctl02_ddlPreferenceOptions', '14');
            setTimeout(() => {
                page.click('#ctl00_cphLeftColumn_ctl02_btnSetPreference');
            }, 1000);

            await page.waitForSelector('.notification-success', {
                timeout: 5000
            });

        }

        return 'Sucesso';

    } catch (e) {
        console.error('Erro ao verificar ambição:', e);
        return false;
    }
}


async function finalizarMusica(page, urlDomain) {
    try {

        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Character/Songs`);
        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_repNewSongs_ctl01_lnkSong', {
            timeout: 2000
        });

        await page.click('#ctl00_cphLeftColumn_ctl00_repNewSongs_ctl01_lnkSong');

        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_btnFinishSong', {
            timeout: 20000
        });

        await page.click('#ctl00_cphLeftColumn_ctl00_btnFinishSong');

        await page.waitForSelector('.ui-dialog-buttonpane .ui-button', {
            timeout: 20000
        });

        await page.evaluate(() => {
            const buttons = document.querySelectorAll('.ui-dialog-buttonpane .ui-button');
            buttons.forEach(button => {
                if (button.textContent.trim() === 'Sim') {
                    button.click();
                }
            });
        });

        await page.waitForNavigation({
            waitUntil: 'networkidle2'
        });




        return 'Sucesso';

    }
    catch (e) {
        console.log(e.message);
        return
    }

}

async function irAcademia(page, urlDomain) {
    try {

        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/City`);
        await page.waitForSelector('#mnuToolTipLocales a', {
            timeout: 2000
        });

        await page.click('#mnuToolTipLocales a');

        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_ddlLocaleType', {
            timeout: 2000
        });

        await page.select('#ctl00_cphLeftColumn_ctl00_ddlLocaleType', '11');
        await page.click('#ctl00_cphLeftColumn_ctl00_btnFind');

        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_repLocales_ctl01_lnkMoveToLocale', { timeout: 2000 });

        await page.click('#ctl00_cphLeftColumn_ctl00_repLocales_ctl01_lnkMoveToLocale');

        return 'Sucesso';
    } catch (e) {
        console.log(e.message);
        return e.message;
    }
}

async function usarPersonalTrainer(page, urlDomain) {

    try {
        const resultIrAcademia = await irAcademia(page, urlDomain);
        console.log(resultIrAcademia);
        if (resultIrAcademia == 'Sucesso') {
            console.log(page.url());
            await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Locale/WorkOut/`);
            await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_btnWorkOut', {
                timeout: 2000
            });

            await page.click('#ctl00_cphLeftColumn_ctl00_btnWorkOut');

            await page.waitForSelector('.notification-success', {
                timeout: 2000
            });

            return 'Sucesso';
        }


        return 'Erro ao usar Personal Trainer';
    }
    catch (e) {
        console.log(e.message);
        return e.message;
    }

}
async function irHotel(page, urlDomain) {
    try {

        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/City`);
        await page.waitForSelector('#mnuToolTipLocales a', {
            timeout: 2000
        });

        await page.click('#mnuToolTipLocales a');

        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_ddlLocaleType', {
            timeout: 2000
        });

        await page.select('#ctl00_cphLeftColumn_ctl00_ddlLocaleType', '32');
        await page.click('#ctl00_cphLeftColumn_ctl00_btnFind');

        await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_repLocales_ctl01_lnkMoveToLocale', { timeout: 2000 });

        await page.click('#ctl00_cphLeftColumn_ctl00_repLocales_ctl01_lnkMoveToLocale');

        return 'Sucesso';
    } catch (e) {
        console.log(e.message);
        return e.message;
    }
}
async function verificarSaude(page, urlDomain) {
    try {
        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Character`)
        // Seleciona o valor do segundo `tr` com a classe `sortkey` e converte para número
        const nivelSaude = await page.evaluate(() => {
            const spanElement = document.querySelectorAll("table.width100 tr")[1].querySelector("span.sortkey");
            return spanElement ? Number(spanElement.textContent.trim()) : null;
        });

        let result;
        if (nivelSaude >= 80) {
            await malhar(page, urlDomain)
            result = await irAcademia(page, urlDomain)
        }
        else {
            await descansar(page, urlDomain)
            result = await irHotel(page, urlDomain)
        }
        return result;
    }
    catch (e) {
        console.log(e.message);
        return e.message;
    }
}

async function verificarMusica(page, urlDomain, musicName = null, gender = null, melody = null, tempo = null) {
    await page.goto(`${urlDomain}/World/Popmundo.aspx/Character/Songs/`);

    // Extraindo o nível da letra (segundo <td>) e o nível da melodia (terceiro <td>)
    const [letraValue, melodiaValue] = await page.evaluate(() => {
        const tableRow = document.querySelector('table.data tbody tr.odd');
        const letraTd = tableRow?.children[1]; // segundo <td>
        const melodiaTd = tableRow?.children[2]; // terceiro <td>

        const letra = letraTd?.querySelector('span.sortkey')?.innerText || null;
        const melodia = melodiaTd?.querySelector('span.sortkey')?.innerText || null;

        return [letra, melodia];
    });

    if (letraValue == 100 && melodiaValue == 100) {
        if (!(musicName && gender && melody && tempo)) {
            await finalizarMusica(page, urlDomain)
            await falarComImprensa(page, urlDomain)
        }
        else {
            await finalizarMusica(page, urlDomain)
            await comporMusica(page, urlDomain)
            await criarMusica(page, urlDomain, musicName, gender, melody, tempo)
        }
    }

    return 'Sucesso';


}


async function irJantar(page, urlDomain) {

    await goToPage(page, `${urlDomain}/World/Popmundo.aspx/City`);
    await page.waitForSelector('#mnuToolTipLocales a', {
        timeout: 2000
    });

    await page.click('#mnuToolTipLocales a');

    await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_ddlLocaleType', {
        timeout: 2000
    });

    await page.select('#ctl00_cphLeftColumn_ctl00_ddlLocaleType', '50');
    await page.click('#ctl00_cphLeftColumn_ctl00_btnFind');

    await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_repLocales_ctl01_lnkMoveToLocale', { timeout: 2000 });

    await page.click('#ctl00_cphLeftColumn_ctl00_repLocales_ctl01_lnkMoveToLocale');

    await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Locale/RestaurantHaveDinner/`);

    await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_ddlOwnMealType ', {
        timeout: 2000
    });

    await page.select('#ctl00_cphLeftColumn_ctl00_ddlOwnMealType', '5');

    await page.waitForSelector('#ctl00_cphLeftColumn_ctl00_btnOrderOwnMeal ', {
        timeout: 2000
    });
    await page.click('#ctl00_cphLeftColumn_ctl00_btnOrderOwnMeal');
    //esperar a pagina recarregar
    await page.waitForNavigation({
        waitUntil: 'networkidle2'
    });
    return 'Sucesso';

}


async function pagarEquipe(page, urlDomain) {

    try {
        await goToPage(page, `${urlDomain}/World/Popmundo.aspx/Artist/Crew/`);
        await page.waitForSelector('#ctl00_cphLeftColumn_ctl01_ddlCashBonus', {
            timeout: 2000
        });

        // Buscar o select de id ctl00_cphLeftColumn_ctl01_ddlCashBonus e selecionar a option com o valor fornecido
        await page.select('#ctl00_cphLeftColumn_ctl01_ddlCashBonus', '20');

        await page.click('#ctl00_cphLeftColumn_ctl01_btnCashBonus');

        await page.waitForNavigation({
            waitUntil: 'networkidle2'
        });
        return 'Sucesso';
    } catch (e) {
        console.log(e.message);
        return e.message;
    }
}
async function startBrowser() {
    const browser = await puppeteer.launch({
        executablePath: chromium.path,
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    return browser;
}


async function loginPopmundo(browser, login, password, char) {
    const page = await browser.newPage();
    await page.goto('http://www.popmundo.com', {
        waitUntil: 'networkidle2'
    });

    await page.waitForSelector('#ctl00_cphRightColumn_ucLogin_txtUsername', {
        timeout: 2000
    });
    await page.waitForSelector('#ctl00_cphRightColumn_ucLogin_txtPassword', {
        timeout: 2000
    });
    await page.type('#ctl00_cphRightColumn_ucLogin_txtUsername', login);
    await page.type('#ctl00_cphRightColumn_ucLogin_txtPassword', password);
    await page.click('input[type="submit"][name="ctl00$cphRightColumn$ucLogin$btnLogin"]');
    await page.waitForNavigation({
        waitUntil: 'networkidle2'
    });

    let url = page.url();
    if (url.includes("ChooseCharacter")) {
        // Seleciona todas as divs com a classe "box"
        const characterDivs = await page.$$('.box');

        for (let div of characterDivs) {
            // Encontra o h2 dentro da div e verifica se o texto é igual ao nome do char
            const characterName = await div.$eval('h2', h2 => h2.textContent.trim());

            if (characterName === char) {
                // Clica no botão de submissão dentro da div correspondente
                const submitButton = await div.$('input[type="submit"]');
                await submitButton.click();
                await page.waitForNavigation({
                    waitUntil: 'networkidle2'
                });
                break;
            }
        }
    }
    let urlDomain = url.substring(0, url.indexOf('.com') + 4);

    console.log('Usuário logado com sucesso.');

    return {
        page,
        urlDomain
    };
}
async function selecionarSelect(page, selectId, selectValue) {
    console.log(selectId);
    const selectedValue = await page.evaluate(() => {
        const select = document.querySelector(`#${selectId}`);
        console.log(select);
        return select ? select.value : null;
    });

    if (selectedValue === selectValue) {
        console.log('A opção já está selecionada.');
        return 'Sucesso';
    }

    await page.select(selectId, selectValue);
}

async function goToPage(page, urlBase) {
    await page.goto(urlBase, {
        waitUntil: 'networkidle2'
    });

    if (!page.url().includes(urlBase)) {
        console.log('Erro ao acessar a página.');
        throw new Error('Erro ao acessar a página.');
    }
}

async function initialSetup(login, senha, nomeChar) {
    try {

        const browser = await startBrowser();
        const {
            page,
            urlDomain
        } = await loginPopmundo(browser, login, senha, nomeChar);

        return {
            browser,
            page,
            urlDomain
        };

    } catch (error) {
        console.error(error.message)
        return null;
    }
}


async function mudarLazer(page, urlDomain, selectValue, palavrasEsperadas) {
    try {
        const urlBase = `${urlDomain}/World/Popmundo.aspx/Character/Focus/`;
        console.log('entrando na pagina de foco')
        await page.goto(urlBase, {
            waitUntil: 'networkidle2'
        });

        if (!page.url().includes('/World/Popmundo.aspx/Character/Focus/')) {
            console.log('Erro ao acessar a página de composição musical.');
            throw new Error('Erro ao acessar a página de composição musical.');
        }

        // Verificar se a opção já está selecionada
        const selectedValue = await page.evaluate(() => {
            const select = document.querySelector('#ctl00_cphLeftColumn_ctl00_ddlPriorities');
            return select ? select.value : null;
        });

        if (selectedValue === selectValue) {
            console.log('A opção já está selecionada.');
            return 'Sucesso';
        }
        console.log('selecionando a opção')
        // Buscar o select de id ctl00_cphLeftColumn_ctl00_ddlPriorities e selecionar a option com o valor fornecido
        await page.select('#ctl00_cphLeftColumn_ctl00_ddlPriorities', selectValue);


        // Clicar no input submit de id = ctl00_cphLeftColumn_ctl00_btnSetPriority
        await page.click('#ctl00_cphLeftColumn_ctl00_btnSetPriority');

        await page.waitForNavigation({
            waitUntil: 'networkidle2'
        });

        return 'Sucesso';
    } catch (e) {
        console.log('Erro ao mudar foco');
        return e.message;
    }
}

async function passear(page, urlDomain) {
    return mudarLazer(page, urlDomain, '18', ['passear', 'scene']);
}

async function descansar(page, urlDomain) {
    return mudarLazer(page, urlDomain, '1', ['descansar', 'rest']);
}

async function malhar(page, urlDomain) {
    return mudarLazer(page, urlDomain, '6', ['malhar', 'gym']);
}




async function usarItem(page, urlDomain, nomeItem) {
    try {
        await page.goto(`${urlDomain}/World/Popmundo.aspx/Character/Items/`);

        // Espera pelo carregamento da tabela
        await page.waitForSelector('#checkedlist', {
            timeout: 5000
        });

        // Executa dentro do contexto da página
        let inputImageId = await page.evaluate((nomeItem) => {
            // Encontra a TR que contém o texto do item (tolerante a espaços extras ou textos adicionais)
            const row = Array.from(document.querySelectorAll('tr')).find(tr =>
                tr.innerText.trim().includes(nomeItem)
            );

            if (row) {
                let rowInputImage = row.querySelector('input[type="image"]');
                return rowInputImage.id;
            } else {
                return null;
            }
        }, nomeItem);

        if (inputImageId) {
            await page.click(`#${inputImageId}`);
            await page.waitForNavigation({
                waitUntil: 'networkidle2'
            });
            console.log(`#${inputImageId}`);
            return 'Sucesso';
        } else {
            console.log(`Erro: Botão de usar "${nomeItem}" não encontrado.`);
            throw new Error(`Erro: Botão de usar "${nomeItem}" não encontrado.`);
        }

    } catch (e) {
        console.log('Erro:', e.message);
    }
}


async function mudarFoco(page, urlDomain, selectValue, palavrasEsperadas) {
    const urlBase = `${urlDomain}/World/Popmundo.aspx/Character/Focus/`;

    await page.goto(urlBase, {
        waitUntil: 'networkidle2'
    });

    if (!page.url().includes('/World/Popmundo.aspx/Character/Focus/')) {
        console.log('Erro ao acessar a página de composição musical.');
        throw new Error('Erro ao acessar a página de composição musical.');
    }

    // Verificar se a opção já está selecionada
    const selectedValue = await page.evaluate(() => {
        const select = document.querySelector('#ctl00_cphLeftColumn_ctl01_ddlWorkTypes');
        return select ? select.value : null;
    });

    if (selectedValue === selectValue) {
        console.log('A opção já está selecionada.');
        return 'Sucesso';
    }

    // Buscar o select de id ctl00_cphLeftColumn_ctl01_ddlWorkTypes e selecionar a option com o valor fornecido
    await page.select('#ctl00_cphLeftColumn_ctl01_ddlWorkTypes', selectValue);

    if (selectValue === '2' || selectValue === '19') {
        try {
            await page.waitForSelector('#ctl00_cphLeftColumn_ctl01_ddlExtras', {
                timeout: 2000
            });
        } catch (error) {
            console.log('Não foi possível mudar para esse foco.');
            return 'Não foi possível mudar para esse foco';
        }
        // Buscar o select de id ctl00_cphLeftColumn_ctl01_ddlExtras e selecionar a option de índice 2
        const options = await page.$$('#ctl00_cphLeftColumn_ctl01_ddlExtras option');
    }
    // Clicar no input submit de id = ctl00_cphLeftColumn_ctl01_btnSetWorkType
    await page.click('#ctl00_cphLeftColumn_ctl01_btnSetWorkType');

    await page.waitForNavigation({
        waitUntil: 'networkidle2'
    });

    // Verifica se o segundo <strong> do segundo <p> contém uma das palavras esperadas
    const secondStrong = await page.evaluate(() => {
        const pTags = document.querySelectorAll('.float_left.characterPresentation p');
        if (pTags.length >= 2) {
            const strongTags = pTags[1].querySelectorAll('strong');
            if (strongTags.length >= 2) {
                return strongTags[1].innerText.toLowerCase();
            }
        }
        return '';
    });

    for (const palavra of palavrasEsperadas) {
        if (secondStrong.includes(palavra)) {
            console.log(`Sucesso: O segundo <strong> contém a palavra esperada "${palavra}".`);
            return 'Sucesso';
        }
    }

    console.log('Erro: O segundo <strong> não contém as palavras esperadas.');
    throw new Error('Erro: O segundo <strong> não contém as palavras esperadas.');
}

async function ensaiarCena(page, urlDomain) {
    return mudarFoco(page, urlDomain, '19', ['ensaiar', 'scene']);
}

async function comporMusica(page, urlDomain) {
    return mudarFoco(page, urlDomain, '2', ['música', 'music', 'song']);
}

async function falarComImprensa(page, urlDomain) {
    return mudarFoco(page, urlDomain, '9', ['imprensa', 'press']);
}

async function cadastrarChars(login, senha) {
    let characters = []; // Inicializa a variável characters para garantir que sempre tenha um valor

    try {
        let browser = await startBrowser();

        const page = await browser.newPage();
        await page.goto('http://www.popmundo.com', {
            waitUntil: 'networkidle2'
        });

        await page.waitForSelector('#ctl00_cphRightColumn_ucLogin_txtUsername', {
            timeout: 2000
        });
        await page.waitForSelector('#ctl00_cphRightColumn_ucLogin_txtPassword', {
            timeout: 2000
        });
        await page.type('#ctl00_cphRightColumn_ucLogin_txtUsername', login);
        await page.type('#ctl00_cphRightColumn_ucLogin_txtPassword', senha);
        await page.click('input[type="submit"][name="ctl00$cphRightColumn$ucLogin$btnLogin"]');
        await page.waitForNavigation({
            waitUntil: 'networkidle2'
        });

        // Verifica se está na página de escolha de personagem
        let url = page.url();
        if (url.includes("ChooseCharacter")) {
            // Extrai todos os personagens
            characters = await page.evaluate(() => {
                let charElements = document.querySelectorAll('.box.clear');
                let chars = [];

                charElements.forEach(charElement => {
                    let nomeCompleto = charElement.querySelector('h2 a').textContent.trim();
                    let id = charElement.querySelector('.idHolder').textContent.trim();

                    chars.push({
                        nomeCompleto,
                        id
                    });
                });

                return chars;
            });

            // Exibe os personagens extraídos
            console.log("Personagens cadastrados:", characters);
        }

        await browser.close();
    } catch (e) {
        console.error("Erro no cadastro de personagens:", e);
        return null;
    }

    return characters.length > 0 ? characters : null; // Garante que sempre retorne um valor, seja characters ou null
}


async function criarMusica(page, urlDomain, musicName, gender, melody, tempo) {

    //https://75.popmundo.com/World/Popmundo.aspx/Character/Songs/3327035
    const urlBase = `${urlDomain}/World/Popmundo.aspx/Character/SongCreate`;
    //clicar no <a> que tem href="/World/Popmundo.aspx/Character/SongCreate"
    await page.goto(urlBase, {
        waitUntil: 'networkidle2'
    });

    await page.select(`#ctl00_cphLeftColumn_ctl00_ddlGenreTypes`, gender);
    await page.select('#ctl00_cphLeftColumn_ctl00_ddlMelodyTypes', melody);
    await page.select('#ctl00_cphLeftColumn_ctl00_ddlTempoTypes', tempo);
    await page.type('#ctl00_cphLeftColumn_ctl00_txtSongName', musicName);
    await page.click('#ctl00_cphLeftColumn_ctl00_btnCreateSong');
    await page.waitForNavigation({
        waitUntil: 'networkidle2'
    });
    await page.select('#ctl00_cphLeftColumn_ctl00_ddlAddInstrument', '-1');
    await page.click('#ctl00_cphLeftColumn_ctl00_btnAddInstrument');
    await page.waitForNavigation({
        waitUntil: 'networkidle2'
    });
    return 'Sucesso';

}
