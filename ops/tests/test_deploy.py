import json, os, pathlib, subprocess, tempfile, unittest
SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'deploy.sh'
NEW='a'*40
OLD='b'*40
class DeploymentTest(unittest.TestCase):
 def run_deploy(self, failure='', certificate=True):
  temp=tempfile.TemporaryDirectory(prefix='nishiohub-deploy-'); self.addCleanup(temp.cleanup)
  base=pathlib.Path(temp.name); tools=base/'bin';tools.mkdir();log=base/'calls'
  for sha in [NEW,OLD]:
   folder=base/'releases'/sha;folder.mkdir(parents=True);(folder/'docker-compose.yml').write_text('services: {}')
  (base/'.env').write_text('test-only');(base/'.deployed-sha').write_text(OLD)
  if certificate:
   cert=base/'certbot/conf/live/nishiohub.com/fullchain.pem';cert.parent.mkdir(parents=True);cert.write_text('fixture')
  mock='''#!/usr/bin/env python3
import os,sys,json
with open(os.environ['MOCK_LOG'],'a') as f:f.write(json.dumps([os.path.basename(sys.argv[0]),os.environ.get('RELEASE_SHA'),sys.argv[1:]])+'\\n')
a=sys.argv[1:]
if os.environ.get('FAIL')=='health' and os.path.basename(sys.argv[0])=='curl':sys.exit(1)
if os.path.basename(sys.argv[0])=='docker' and 'pg_dump' in a:print('backup fixture')
if os.environ.get('FAIL')=='build' and 'build' in a:sys.exit(1)
if os.environ.get('FAIL')=='migration' and 'db:migrate' in a:sys.exit(1)
if os.environ.get('FAIL')=='activation' and os.environ.get('RELEASE_SHA')=='a'*40 and 'up' in a and 'api' in a:sys.exit(1)
'''
  for tool in ['docker','curl']:
   p=tools/tool;p.write_text(mock);p.chmod(0o755)
  env={**os.environ,'PATH':str(tools)+':'+os.environ['PATH'],'MOCK_LOG':str(log),'FAIL':failure}
  result=subprocess.run(['bash',str(SCRIPT),str(base),NEW],env=env,text=True,capture_output=True)
  calls=[json.loads(line) for line in log.read_text().splitlines()]
  return result,base,calls
 def test_success_and_backup_before_migration(self):
  result,base,calls=self.run_deploy();self.assertEqual(0,result.returncode,result.stderr)
  self.assertEqual(NEW,(base/'.deployed-sha').read_text().strip())
  self.assertTrue(list((base/'backups').glob('*.dump')))
  args=[c[2] for c in calls]
  self.assertLess(next(i for i,a in enumerate(args) if 'pg_dump' in a),next(i for i,a in enumerate(args) if 'db:migrate' in a))
  self.assertEqual(2,sum(c[0]=='curl' for c in calls))
 def test_build_failure_does_not_migrate_or_activate(self):
  result,base,calls=self.run_deploy('build');self.assertNotEqual(0,result.returncode)
  self.assertFalse(any('db:migrate' in c[2] for c in calls));self.assertEqual(OLD,(base/'.deployed-sha').read_text())
 def test_migration_failure_keeps_existing_application(self):
  result,base,calls=self.run_deploy('migration');self.assertNotEqual(0,result.returncode)
  self.assertFalse(any('up' in c[2] and 'api' in c[2] for c in calls));self.assertEqual(OLD,(base/'.deployed-sha').read_text())
 def test_failed_activation_restores_previous_application(self):
  result,base,calls=self.run_deploy('activation');self.assertNotEqual(0,result.returncode)
  self.assertTrue(any(c[1]==OLD and 'up' in c[2] and 'api' in c[2] for c in calls));self.assertEqual(OLD,(base/'.deployed-sha').read_text())
 def test_failed_https_check_restores_previous_application(self):
  result,base,calls=self.run_deploy('health');self.assertNotEqual(0,result.returncode)
  self.assertTrue(any(c[1]==OLD and 'up' in c[2] and 'nginx' in c[2] for c in calls));self.assertEqual(OLD,(base/'.deployed-sha').read_text())
 def test_first_certificate_uses_webroot_bootstrap(self):
  result,base,calls=self.run_deploy(certificate=False);self.assertEqual(0,result.returncode,result.stderr)
  self.assertTrue(any(any('compose.bootstrap.yml' in arg for arg in c[2]) for c in calls))
  self.assertTrue(any('certbot' in c[2] and any('certonly' in arg for arg in c[2]) for c in calls))
if __name__=='__main__':unittest.main()
