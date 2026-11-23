import pathlib,subprocess,tempfile,unittest
SCRIPT=pathlib.Path(__file__).resolve().parents[1]/'prepare-known-hosts.sh'
class KnownHostsTest(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(prefix='host-key-test-');self.addCleanup(self.temp.cleanup);self.root=pathlib.Path(self.temp.name)
  key=self.root/'server';subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','','-f',str(key)],check=True)
  self.public=key.with_suffix('.pub').read_text().strip();self.fields=' '.join(self.public.split()[:2]);self.output=self.root/'known_hosts'
 def prepare(self,content,port='22'):
  return subprocess.run(['bash',str(SCRIPT),'server.example.test',port,str(self.output)],input=content,text=True,capture_output=True)
 def test_raw_server_key_binds_default_host(self):
  r=self.prepare(self.public);self.assertEqual(0,r.returncode,r.stderr);self.assertEqual('server.example.test '+self.fields,self.output.read_text().strip());self.assertNotIn(self.fields,r.stdout+r.stderr)
 def test_raw_key_binds_custom_port_and_handles_crlf(self):
  r=self.prepare(self.public+'\r\n','2222');self.assertEqual(0,r.returncode,r.stderr);self.assertTrue(self.output.read_text().startswith('[server.example.test]:2222 '))
 def test_existing_known_hosts_retains_host_restrictions(self):
  r=self.prepare('another.example.test '+self.fields);self.assertNotEqual(0,r.returncode);self.assertIn('do not match',r.stderr)
 def test_matching_known_hosts_passes(self):
  self.assertEqual(0,self.prepare('server.example.test '+self.fields).returncode)
 def test_hashed_matching_host_passes(self):
  self.output.write_text('server.example.test '+self.fields+'\n');subprocess.run(['ssh-keygen','-H','-f',str(self.output)],capture_output=True,check=True)
  self.assertEqual(0,self.prepare(self.output.read_text()).returncode)
 def test_fingerprints_empty_and_private_keys_rejected(self):
  for content in ['', '256 SHA256:not-a-key root@server (ED25519)','-----BEGIN OPENSSH PRIVATE KEY-----']:
   self.assertNotEqual(0,self.prepare(content).returncode)
if __name__=='__main__':unittest.main()
