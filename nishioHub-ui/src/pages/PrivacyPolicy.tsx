import { MainLayout } from "@/components/layout/main-layout";
import { Separator } from "@/components/ui/separator";
import { Helmet } from "react-helmet";

export default function PrivacyPolicyPage() {
  return (
    <MainLayout>
      <Helmet>
        <title>Privacy Policy - nishioHub</title>
      </Helmet>
      
      <div className="container max-w-4xl mx-auto py-12 px-4">
        <h1 className="text-4xl font-bold mb-6">Privacy Policy</h1>
        <p className="text-muted-foreground mb-8">Last updated: July 21, 2025</p>
        
        <div className="prose dark:prose-invert max-w-none">
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">1. Introduction</h2>
            <p>
              Welcome to nishioHub ("we," "our," or "us"). We are committed to protecting your privacy and personal data. 
              This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our website and services.
            </p>
            <p>
              Please read this Privacy Policy carefully. If you do not agree with the terms of this Privacy Policy, please do not access the site or use our services.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">2. Information We Collect</h2>
            
            <h3 className="text-xl font-medium mt-6 mb-3">2.1 Personal Information</h3>
            <p>We may collect personal information that you voluntarily provide to us when you:</p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Create an account or profile</li>
              <li>Book or provide mentorship services</li>
              <li>Complete forms or surveys</li>
              <li>Participate in discussions or feedback</li>
              <li>Contact customer support</li>
              <li>Make payments</li>
            </ul>
            
            <p>This personal information may include:</p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Name, email address, and phone number</li>
              <li>Professional background and expertise</li>
              <li>Profile pictures</li>
              <li>Payment information</li>
              <li>Communication preferences</li>
              <li>Any other information you choose to provide</li>
            </ul>
            
            <h3 className="text-xl font-medium mt-6 mb-3">2.2 Automatically Collected Information</h3>
            <p>When you access our website, we automatically collect certain information about your device and usage, including:</p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Device type, operating system, and browser type</li>
              <li>IP address and general location</li>
              <li>Pages visited and features used</li>
              <li>Time spent on the platform</li>
              <li>Referring website or source</li>
              <li>Network connection type</li>
            </ul>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">3. How We Use Your Information</h2>
            <p>We may use the information we collect for various purposes, including to:</p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Provide, maintain, and improve our services</li>
              <li>Process transactions and send related information</li>
              <li>Verify your identity and eligibility for services</li>
              <li>Connect mentees with appropriate mentors</li>
              <li>Communicate with you about services, updates, and promotions</li>
              <li>Respond to your comments, questions, and requests</li>
              <li>Monitor and analyze trends, usage, and activities</li>
              <li>Detect, prevent, and address technical issues or fraudulent activities</li>
              <li>Personalize your experience</li>
            </ul>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">4. Sharing Your Information</h2>
            <p>We may share your personal information with the following parties:</p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">4.1 Within the Platform</h3>
            <p>
              Certain information, such as your name, profile picture, professional background, and reviews, 
              may be visible to other users as part of the mentorship matching process. 
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">4.2 Service Providers</h3>
            <p>
              We may share information with third-party service providers who perform services on our behalf, 
              such as payment processing, data analysis, email delivery, hosting, customer service, and marketing assistance.
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">4.3 Legal Requirements</h3>
            <p>
              We may disclose your information if required to do so by law or in response to valid requests by public authorities 
              (e.g., court order, government request).
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">4.4 Business Transfers</h3>
            <p>
              If we are involved in a merger, acquisition, or sale of all or a portion of our assets, 
              your information may be transferred as part of that transaction.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">5. Your Choices and Rights</h2>
            <p>You have several choices regarding the use of your information:</p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Access and update your account information through your profile settings</li>
              <li>Opt-out of marketing communications by following the unsubscribe instructions</li>
              <li>Request deletion of your personal data (subject to certain exceptions)</li>
              <li>Set your browser to refuse cookies or alert you when cookies are being sent</li>
            </ul>
            
            <p>
              Depending on your location, you may have additional rights regarding your personal data, 
              such as the right to access, correct, delete, restrict processing, or data portability.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">6. Data Security</h2>
            <p>
              We implement appropriate security measures to protect the security of your personal information. 
              However, please be aware that no method of transmission over the Internet or electronic storage is 100% secure. 
              While we strive to use commercially acceptable means to protect your personal information, we cannot guarantee its absolute security.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">7. Children's Privacy</h2>
            <p>
              Our services are not intended for individuals under the age of 18. 
              We do not knowingly collect personal information from children under 18. 
              If we learn we have collected personal information from a child under 18, we will delete that information.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">8. Changes to this Privacy Policy</h2>
            <p>
              We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page 
              and updating the "Last Updated" date at the top. You are advised to review this Privacy Policy periodically for any changes.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section>
            <h2 className="text-2xl font-semibold mb-4">9. Contact Us</h2>
            <p>
              If you have questions or concerns about this Privacy Policy or our data practices, please contact us at:
            </p>
            <div className="mt-4">
              <p className="font-medium">nishioHub Support</p>
              <p>Email: privacy@nishioHub.example</p>
              <p>Phone: +1 (555) 123-4567</p>
              <p>Address: 123 Mentoring Way, Knowledge City, 94000</p>
            </div>
          </section>
        </div>
      </div>
    </MainLayout>
  );
}