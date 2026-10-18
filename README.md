"# cyber" 
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh -T git@github.com

cd ~/cyber
git remote set-url origin git@github.com:thomasPeelmanUCLL/cyber.git
git remote -v
git push