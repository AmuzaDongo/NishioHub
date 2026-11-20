import { MainLayout } from "@/components/layout/main-layout";
import { Separator } from "@/components/ui/separator";
import { Helmet } from "react-helmet";

export default function TermsOfServicePage() {
  return (
    <MainLayout>
      <Helmet>
        <title>Terms of Service - nishioHub</title>
      </Helmet>
      
      <div className="container max-w-4xl mx-auto py-12 px-4">
        <h1 className="text-4xl font-bold mb-6">Terms of Service</h1>
        <p className="text-muted-foreground mb-8">Last updated: July 21, 2025</p>
        
        <div className="prose dark:prose-invert max-w-none">
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">1. Acceptance of Terms</h2>
            <p>
              Welcome to nishioHub. By accessing or using our website, mobile applications, and services (collectively, the "Services"), 
              you agree to be bound by these Terms of Service ("Terms"). These Terms constitute a legally binding agreement between you 
              and nishioHub ("we," "us," or "our"). If you do not agree to these Terms, please do not access or use our Services.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">2. Eligibility</h2>
            <p>
              You must be at least 18 years old to create an account and use our Services. By creating an account and using our Services, 
              you represent and warrant that:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>You are at least 18 years of age;</li>
              <li>You can form a legally binding contract with nishioHub;</li>
              <li>You are not a person who is barred from using the Services under the laws of your country of residence or any other applicable jurisdiction;</li>
              <li>You will comply with these Terms and all applicable local, state, national, and international laws, rules, and regulations.</li>
            </ul>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">3. Account Registration</h2>
            <p>
              To access certain features of our Services, you must register for an account. When you register, you agree to provide 
              accurate, current, and complete information about yourself and to update this information to maintain its accuracy. 
              You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. 
              You agree to notify us immediately of any unauthorized use of your account or any other breach of security.
            </p>
            <p className="mt-4">
              We reserve the right to suspend or terminate your account if any information provided during the registration process or 
              thereafter proves to be inaccurate, incomplete, or fraudulent.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">4. User Roles</h2>
            <h3 className="text-xl font-medium mt-6 mb-3">4.1 Mentees</h3>
            <p>
              As a mentee, you seek guidance, advice, or knowledge from mentors on our platform. 
              You agree to respect mentors' time and expertise, provide accurate information regarding your goals and needs, 
              and comply with the cancellation and payment policies outlined herein.
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">4.2 Mentors</h3>
            <p>
              As a mentor, you offer your expertise, guidance, and knowledge to mentees. You agree to:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Provide accurate information about your qualifications, experience, and expertise;</li>
              <li>Deliver services as described in your service offerings;</li>
              <li>Respond to mentee inquiries and bookings within a reasonable timeframe;</li>
              <li>Maintain professionalism in all interactions with mentees;</li>
              <li>Comply with all applicable laws and regulations related to providing your services.</li>
            </ul>
            <p>
              nishioHub reserves the right to review mentor applications and remove mentors who do not meet our standards 
              or violate these Terms.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">5. Service Bookings and Payments</h2>
            <h3 className="text-xl font-medium mt-6 mb-3">5.1 Booking Process</h3>
            <p>
              Mentees can book services offered by mentors through our platform. By booking a service, 
              mentees agree to pay the listed price and comply with the mentor's availability and cancellation policies.
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">5.2 Payments</h3>
            <p>
              All payments are processed through our secure payment system. Prices are listed in the applicable currency and 
              may be subject to taxes or fees as required by law. Payment is required at the time of booking.
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">5.3 Service Fees</h3>
            <p>
              nishioHub charges a service fee to maintain the platform and provide customer support. 
              This fee is included in the total price shown to mentees and deducted from payments to mentors.
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">5.4 Cancellations and Refunds</h3>
            <p>
              Cancellation policies may vary by mentor. Generally:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>If a mentee cancels more than 24 hours before the scheduled session, a full refund will be issued;</li>
              <li>If a mentee cancels less than 24 hours before the scheduled session, the mentor may charge a cancellation fee;</li>
              <li>If a mentor cancels a session, the mentee will receive a full refund or the option to reschedule;</li>
              <li>In case of technical difficulties or unforeseen circumstances, nishioHub will review refund requests on a case-by-case basis.</li>
            </ul>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">6. User Content and Conduct</h2>
            <h3 className="text-xl font-medium mt-6 mb-3">6.1 User Content</h3>
            <p>
              "User Content" includes any text, images, videos, reviews, messages, or other materials that users upload, post, or share 
              through our Services. You retain ownership rights to your User Content, but you grant nishioHub a non-exclusive, 
              worldwide, royalty-free license to use, reproduce, modify, adapt, publish, translate, and distribute your User Content 
              in connection with providing and promoting our Services.
            </p>
            
            <h3 className="text-xl font-medium mt-6 mb-3">6.2 Prohibited Conduct</h3>
            <p>
              You agree not to:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Violate any law, regulation, or third-party rights;</li>
              <li>Post or transmit any content that is unlawful, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, or otherwise objectionable;</li>
              <li>Impersonate any person or entity or falsely state or otherwise misrepresent your affiliation with a person or entity;</li>
              <li>Interfere with or disrupt the Services or servers or networks connected to the Services;</li>
              <li>Attempt to gain unauthorized access to other users' accounts or the Services' technical systems;</li>
              <li>Use the Services for any commercial purpose not expressly permitted by nishioHub;</li>
              <li>Collect or store personal data about other users without their consent;</li>
              <li>Attempt to circumvent any technological measures implemented to protect the Services or enforce these Terms.</li>
            </ul>
            
            <p>
              nishioHub reserves the right to remove any User Content and suspend or terminate accounts of users who violate these guidelines.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">7. Intellectual Property</h2>
            <p>
              The nishioHub name, logo, website, and all content, features, and functionality (including but not limited to all information, 
              software, text, displays, images, video, audio, and the design, selection, and arrangement thereof) are owned by nishioHub or 
              its licensors and are protected by copyright, trademark, patent, trade secret, and other intellectual property or proprietary rights laws.
            </p>
            <p className="mt-4">
              Nothing in these Terms grants you a right or license to use any nishioHub trademarks, logos, or other proprietary information. 
              Any use of the Services not expressly permitted by these Terms is a breach of these Terms and may violate copyright, trademark, 
              and other intellectual property laws.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">8. Limitation of Liability</h2>
            <p>
              To the maximum extent permitted by applicable law, nishioHub and its officers, directors, employees, agents, affiliates, 
              and licensors shall not be liable for any indirect, incidental, special, consequential, or punitive damages, 
              including but not limited to, loss of profits, data, use, goodwill, or other intangible losses, resulting from:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>Your access to or use of or inability to access or use the Services;</li>
              <li>Any conduct or content of any third party on the Services;</li>
              <li>Any content obtained from the Services;</li>
              <li>Unauthorized access, use, or alteration of your transmissions or content;</li>
              <li>The quality or outcomes of mentorship services provided through our platform.</li>
            </ul>
            <p>
              In no event shall our total liability to you for all claims exceed the amount paid by you, if any, 
              for accessing or using our Services during the twelve (12) months preceding the claim.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section className="mb-8">
            <h2 className="text-2xl font-semibold mb-4">9. Changes to These Terms</h2>
            <p>
              We may revise these Terms from time to time. The most current version will always be posted on our website. 
              By continuing to access or use our Services after revisions become effective, you agree to be bound by the revised Terms. 
              If you do not agree to the new Terms, please stop using the Services.
            </p>
          </section>
          
          <Separator className="my-8" />
          
          <section>
            <h2 className="text-2xl font-semibold mb-4">10. Contact Information</h2>
            <p>
              If you have any questions about these Terms, please contact us at:
            </p>
            <div className="mt-4">
              <p className="font-medium">nishioHub Legal Department</p>
              <p>Email: legal@nishioHub.example</p>
              <p>Phone: +1 (555) 123-4567</p>
              <p>Address: 123 Mentoring Way, Knowledge City, 94000</p>
            </div>
          </section>
        </div>
      </div>
    </MainLayout>
  );
}